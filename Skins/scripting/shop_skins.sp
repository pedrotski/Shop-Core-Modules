#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <shop>

#pragma semicolon 1
#pragma newdecls required

#define CATEGORY	"skins"

bool G_bAlreadyUsed[MAXPLAYERS+1];
float G_fDelayBeforeSetSpawn;

ItemId selected_id[MAXPLAYERS+1] = {INVALID_ITEM, ...};

KeyValues kv;
ArrayList hArrayModels;

public Plugin myinfo =
{
	name = "[Shop] Skins",
	author = "FrozDark Feat R1KO, Tonki_Ton)",
	description = "Adds ability to buy skins",
	version = "2.3.0",
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
	HookEvent("player_team", Event_PlayerSpawn);
	
	hArrayModels = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];
	
	for (int i = 0; i < hArrayModels.Length; i++)
	{
		hArrayModels.GetString(i, buffer, sizeof(buffer));
		PrecacheModel(buffer, true);
	}
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "skins_downloads.txt");
	
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
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, "Skins", "");

	char _buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(_buffer, sizeof(_buffer), "skins.txt");

	if (kv != INVALID_HANDLE) delete kv;

	kv = CreateKeyValues("Skins");

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
			
			kv.GetString("ModelT", _buffer, sizeof(_buffer));
			bool result = false;
			if (_buffer[0])
			{
				PrecacheModel(_buffer);
				if (hArrayModels.FindString(_buffer) == -1) hArrayModels.PushString(_buffer);
				
				kv.GetString("ModelT_Arms", _buffer, sizeof(_buffer));
				if (_buffer[0])
				{
					PrecacheModel(_buffer);
					if (hArrayModels.FindString(_buffer) == -1) hArrayModels.PushString(_buffer);
				}
		
				result = true;
			}
			
			kv.GetString("ModelCT", _buffer, sizeof(_buffer));
			if (_buffer[0])
			{
				PrecacheModel(_buffer, true);
				if (hArrayModels.FindString(_buffer) == -1) hArrayModels.PushString(_buffer);
				
				kv.GetString("ModelCT_Arms", _buffer, sizeof(_buffer));
				if (_buffer[0])
				{
					PrecacheModel(_buffer);
					if (hArrayModels.FindString(_buffer) == -1) hArrayModels.PushString(_buffer);
				}
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
	if (isOn || elapsed)
	{
		CS_UpdateClientModel(client);
		
		selected_id[client] = INVALID_ITEM;
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);	
	selected_id[client] = item_id;	
	ProcessPlayer(INVALID_HANDLE, client);
	
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

	switch (GetClientTeam(client))
	{
		case 2:kv.GetString("ModelT", buffer, sizeof(buffer));
		case 3:kv.GetString("ModelCT", buffer, sizeof(buffer));
		default:buffer[0] = 0;
	}

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

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || selected_id[client] == INVALID_ITEM || IsFakeClient(client) || !IsPlayerAlive(client)) return;
	
	CreateTimer(G_fDelayBeforeSetSpawn, ProcessPlayer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ProcessPlayer(Handle timer, any client)
{
	if(!IsClientInGame(client)) return Plugin_Stop;
		
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
		
		switch (GetClientTeam(client))
		{
			case 2 :
			{
				kv.GetString("ModelT", buffer, sizeof(buffer));
				kv.GetString("ModelT_Arms", sArms, sizeof(sArms));
			}
			case 3 :
			{
				kv.GetString("ModelCT", buffer, sizeof(buffer));
				kv.GetString("ModelCT_Arms", sArms, sizeof(sArms));
			}
			default :
			{
				buffer[0] = 
				sArms[0] = '\0';
			}
		}
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