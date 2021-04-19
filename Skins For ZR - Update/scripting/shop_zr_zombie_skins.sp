#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <shop>
//#include <zombiereloaded>
#include <colors_csgo>
#undef REQUIRE_EXTENSIONS
#include <hitboxchanger>	

#pragma semicolon 1
#pragma newdecls required

#define CATEGORY	"skins_zombie"

bool G_bAlreadyUsed[MAXPLAYERS+1];
float G_fDelayBeforeSetSpawn;

ItemId selected_id[MAXPLAYERS+1] = {INVALID_ITEM, ...};

KeyValues kv;
ArrayList hArrayModels;

public Plugin myinfo =
{
	name = "[Shop] CS:GO Zombie Skins for Zombie:Reloaded",
	author = "FrozDark Feat R1KO, Tonki_Ton, Oylsister, Anubis Edition",
	description = "Adds ability to buy skins",
	version = "2.5.0-A",
	url = "https://hlmod.ru/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Shop_GetItemGoldPrice");
	MarkNativeAsOptional("Shop_SetItemGoldPrice");
	MarkNativeAsOptional("Shop_SetItemGoldSellPrice");
	MarkNativeAsOptional("Shop_GetItemGoldSellPrice");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	//HookEvent("player_team", Event_PlayerSpawn); 
	
	hArrayModels = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart()
{
	LoadTranslations("shop_zr_zombie_skins.phrases");

	char buffer[PLATFORM_MAX_PATH];
	
	for (int i = 0; i < hArrayModels.Length; i++)
	{
		hArrayModels.GetString(i, buffer, sizeof(buffer));
		PrecacheModel(buffer, true);
	}
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "zr_skins_zombie_downloads.txt");
	
	if (!File_ReadDownloadList(buffer)) PrintToServer("File not exists %s", buffer);
}

public void OnClientPutInServer(int client)
{
	G_bAlreadyUsed[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
	selected_id[client] = INVALID_ITEM;
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, "Zombies Skins", "");

	char _buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(_buffer, sizeof(_buffer), "zr_skins_zombie.txt");

	if (kv != INVALID_HANDLE) delete kv;

	kv = CreateKeyValues("ZR_Skins_Zombie");

	if (!FileToKeyValues(kv, _buffer)) ThrowError("\"%s\" not parsed", _buffer);

	hArrayModels.Clear();

	kv.Rewind();
	G_fDelayBeforeSetSpawn = kv.GetFloat("delay_before_set_spawn", 0.5);

	char item[64], item_name[64], desc[64];

	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			if (!KvGetSectionName(kv, item, sizeof(item))) continue;
			
			kv.GetString("Model", _buffer, sizeof(_buffer));
			bool result = false;
			if (_buffer[0])
			{
				PrecacheModel(_buffer, true);
				if (hArrayModels.FindString(_buffer) == -1) hArrayModels.PushString(_buffer);
				
				kv.GetString("Model_Arms", _buffer, sizeof(_buffer));
				if (_buffer[0])
				{
					PrecacheModel(_buffer);
					if (hArrayModels.FindString(_buffer) == -1) hArrayModels.PushString(_buffer);
				}

				result = true;
			}
			else if (!result) continue;

			if (Shop_StartItem(category_id, item))
			{
				kv.GetString("name", item_name, sizeof(item_name), item);
				kv.GetString("description", desc, sizeof(desc), "");
				Shop_SetInfo(item_name, desc, kv.GetNum("price", 1000), kv.GetNum("sell_price", 500), Item_Togglable, kv.GetNum("duration", 86400), kv.GetNum("gold_price", -1), kv.GetNum("gold_sell_price", -1));
				Shop_SetLuckChance(kv.GetNum("luckchance", 10));
				Shop_SetHide(view_as<bool>(kv.GetNum("hide", 0)));
				Shop_SetCallbacks(_, OnEquipItem, _, _, _, OnPreviewItem);
				
				if (kv.JumpToKey("Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(kv);
					kv.GoBack();
				}

				Shop_EndItem();
			}
		}
		while (kv.GotoNextKey());
	}
	
	kv.Rewind();
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	// Allow the zombie player to choose or toggle, but player model won't changed
	//if ((isOn || elapsed) && ZR_IsClientHuman(client))
	if ((isOn || elapsed) && GetClientTeam(client) == CS_TEAM_CT)
	{
		CPrintToChat(client, "%t", "Your skins will be changed in the next round");

		selected_id[client] = INVALID_ITEM;

		return Shop_UseOff;
	}
		
	//if ((isOn || elapsed) && ZR_IsClientZombie(client))
	if ((isOn || elapsed) && GetClientTeam(client) == CS_TEAM_T)
	{
		//CS_UpdateClientModel(client);
		CPrintToChat(client, "%t", "Your skin will be changed at the next respawn");
		selected_id[client] = INVALID_ITEM;
		
		return Shop_UseOff;
	}

	Shop_ToggleClientCategoryOff(client, category_id);	
	selected_id[client] = item_id;	
	//ProcessPlayer(INVALID_HANDLE, client);
	Process(INVALID_HANDLE, client);
	
	return Shop_UseOn;
}

public void OnPreviewItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	char buffer[PLATFORM_MAX_PATH];
	
	kv.Rewind();
	if (!kv.JumpToKey(item, false))
	{
		LogError("It seems that registered item \"%s\" not exists in the settings", buffer);
		return;
	}

	kv.GetString("Model", buffer, sizeof(buffer));

	char anim[PLATFORM_MAX_PATH];
	kv.GetString("preview_anim", anim, PLATFORM_MAX_PATH);
	kv.Rewind();

	if (IsPlayerAlive(client) && !G_bAlreadyUsed[client] && buffer[0] && IsModelFile(buffer))
	{
		PreviewSkins(client, buffer, anim);
		G_bAlreadyUsed[client] = true;
		CreateTimer(5.0, AlreadyUsedBack, client);
	}
}

public Action AlreadyUsedBack(Handle timer, int client)
{
	G_bAlreadyUsed[client] = false;
}

void PreviewSkins(int client, const char[] sModel="", const char[] animation = "")
{
	int entity = CreateEntityByName("prop_dynamic_override");
	
	float eye[3];
	GetPlayerEye(client, eye);
	DispatchKeyValue(entity, "model", sModel);
	DispatchKeyValue(entity, "DefaultAnim", animation[0] ? animation:"default");
	DispatchSpawn(entity);

	TeleportEntity(entity, eye, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	SetVariantString("OnUser1 !self:FadeAndKill::5.0:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");

	SDKHook(entity, SDKHook_SetTransmit, SetTransmitSkin);
}

public Action SetTransmitSkin(int entity, int client)
{
	int owner;
	return ((owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) != -1 && (owner != client)) ? Plugin_Handled : Plugin_Continue;
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	CreateTimer(G_fDelayBeforeSetSpawn, Process, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	CreateTimer(G_fDelayBeforeSetSpawn, Process, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Process(Handle timer, any client)
{
	//if (!client || selected_id[client] == INVALID_ITEM || IsFakeClient(client) || !IsPlayerAlive(client) || ZR_IsClientHuman(client)) return;
	if (!client || selected_id[client] == INVALID_ITEM || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) == CS_TEAM_CT) return;
	CreateTimer(0.2, ProcessPlayer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ProcessPlayer(Handle timer, any client)
{
	if(!IsClientInGame(client)) return Plugin_Stop;

	//if(ZR_IsClientHuman(client)) return Plugin_Stop;
	if(GetClientTeam(client) == CS_TEAM_CT) return Plugin_Stop;
		
	char buffer[PLATFORM_MAX_PATH];
	
	if(selected_id[client] != INVALID_ITEM)
	{
		Shop_GetItemById(selected_id[client], buffer, sizeof(buffer));

		kv.Rewind();
		if (!KvJumpToKey(kv, buffer, false))
		{
			LogError("It seems that registered item \"%s\" not exists in the settings", buffer);
			return Plugin_Stop;
		}
		
		char sArms[PLATFORM_MAX_PATH];
		
		kv.GetString("Model", buffer, sizeof(buffer));
		kv.GetString("Model_Arms", sArms, sizeof(sArms));

		if (buffer[0] && IsModelFile(buffer))
		{
			SetEntityModel(client, buffer);
			
			if (sArms[0] && IsModelFile(sArms)) SetEntPropString(client, Prop_Send, "m_szArmsModel", sArms);
			
			kv.GetString("color", buffer, sizeof(buffer));
			if (strlen(buffer) > 7)
			{
				int color[4];
				kv.GetColor("color", color[0], color[1], color[2], color[3]);
				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				SetEntityRenderColor(client, color[0], color[1], color[2], color[3]);
			}
		}
		
		kv.Rewind();
	}
	return Plugin_Stop;
}

bool IsModelFile(const char[] model)
{
	char buf[4];
	File_GetExtension(model, buf, sizeof(buf));
	
	return !strcmp(buf, "mdl", false);
}

char _smlib_empty_twodimstring_array[][] = { { '\0' } };
stock void File_AddToDownloadsTable(char[] path, bool recursive = true, const char[][] ignoreExts = _smlib_empty_twodimstring_array, int size = 0)
{
	if (path[0] == '\0') return;
	
	int len = strlen(path)-1;
	
	if (path[len] == '\\' || path[len] == '/') path[len] = '\0';

	if (FileExists(path)) {
		
		char fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));
		
		if (StrEqual(fileExtension, "bz2", false) || StrEqual(fileExtension, "ztmp", false)) return;
		
		if (Array_FindString(ignoreExts, size, fileExtension) != -1) return;

		AddFileToDownloadsTable(path);
		
		if (StrEqual(fileExtension, "mdl", false)) PrecacheModel(path, true);
	}
	
	else if (recursive && DirExists(path)) {

		char dirEntry[PLATFORM_MAX_PATH];
		Handle __dir = OpenDirectory(path);

		while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) 
		{
			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) continue;
			
			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);
			File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
		}
		
		CloseHandle(__dir);
	}
	else if (FindCharInString(path, '*', true)) {
		
		char fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));

		if (StrEqual(fileExtension, "*")) {

			char
				dirName[PLATFORM_MAX_PATH],
				fileName[PLATFORM_MAX_PATH],
				dirEntry[PLATFORM_MAX_PATH];

			File_GetDirName(path, dirName, sizeof(dirName));
			File_GetFileName(path, fileName, sizeof(fileName));
			StrCat(fileName, sizeof(fileName), ".");

			Handle __dir = OpenDirectory(dirName);
			while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

				if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
					continue;
				}

				if (strncmp(dirEntry, fileName, strlen(fileName)) == 0) {
					Format(dirEntry, sizeof(dirEntry), "%s/%s", dirName, dirEntry);
					File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
				}
			}

			CloseHandle(__dir);
		}
	}

	return;
}

stock void GetPlayerEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
 
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayers);
	TR_GetEndPosition(pos);
}

public bool TraceEntityFilterPlayers(int ent, int Mask)
{
	return (!(0 < ent <= MaxClients));
}

stock bool File_ReadDownloadList(const char[] path)
{
	Handle file = OpenFile(path, "r");
	
	if (file  == INVALID_HANDLE) return false;

	char buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) 
	{
		ReadFileLine(file, buffer, sizeof(buffer));
		
		int pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) buffer[pos] = '\0';
		
		pos = StrContains(buffer, "#");
		if (pos != -1) buffer[pos] = '\0';

		pos = StrContains(buffer, ";");
		if (pos != -1) buffer[pos] = '\0';
		
		TrimString(buffer);
		
		if (buffer[0] == '\0') continue;

		File_AddToDownloadsTable(buffer);
	}

	CloseHandle(file);
	
	return true;
}

stock void File_GetExtension(const char[] path, char[] buffer, int size)
{
	int extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();
	
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock int Array_FindString(const char[][] array, int size, const char[] str, bool caseSensitive=true, int start=0)
{
	if (start < 0) start = 0;

	for (int i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) return i;
	}
	
	return -1;
}

stock bool File_GetFileName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') 
	{
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	int pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) buffer[pos_ext] = '\0';
}

stock bool File_GetDirName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') 
	{
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) 
	{
		pos_start = FindCharInString(path, '\\', true);
		
		if (pos_start == -1) 
		{
			buffer[0] = '\0';
			return;
		}
	}
	
	strcopy(buffer, size, path);
	buffer[pos_start] = '\0';
}

stock bool File_GetBaseName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') 
	{
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) pos_start = FindCharInString(path, '\\', true);
	
	pos_start++;
	
	strcopy(buffer, size, path[pos_start]);
}