#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>

#define PLUGIN_VERSION	"2.1.1"

new Handle:g_hLookupAttachment = INVALID_HANDLE;

new Handle:kv;

new Handle:hTrieEntity[MAXPLAYERS+1];
new Handle:hTrieItem[MAXPLAYERS+1];
new Handle:hTimer[MAXPLAYERS+1];
new String:sClLang[MAXPLAYERS+1][3];

new Handle:hCategories;

new Handle:g_hPreview, bool:g_bPreview,
	Handle:g_hRemoveOnDeath, bool:g_bRemoveOnDeath;

public Plugin:myinfo =
{
    name        = "[Shop] Equipments",
    author      = "FrozDark",
    description = "Equipments component for shop",
    version     = PLUGIN_VERSION,
    url         = "www.hlmod.ru"
};

public OnPluginStart()
{
	new Handle:hGameConf = LoadGameConfigFile("shop_equipments.gamedata");
	if (hGameConf == INVALID_HANDLE)
	{
		SetFailState("gamedata/\"shop_equipments.gamedata.txt\" not found");
	}
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "LookupAttachment");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((g_hLookupAttachment = EndPrepSDKCall()) == INVALID_HANDLE)
	{
		SetFailState("Could not get \"LookupAttachment\" signature");
	}
	CloseHandle(hGameConf);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	hCategories = CreateArray(ByteCountToCells(64));
	
	RegAdminCmd("equipments_reload", Command_Reload, ADMFLAG_ROOT, "Reloads equipments configuration");
	
	g_hPreview = CreateConVar("sm_shop_equipments_preview", "1", "Enables preview for equipments");
	g_bPreview = GetConVarBool(g_hPreview);
	HookConVarChange(g_hPreview, OnConVarChange);
	
	g_hRemoveOnDeath = CreateConVar("sm_shop_equipments_remove_on_death", "1", "Removes a player's equipments on death");
	g_bRemoveOnDeath = GetConVarBool(g_hRemoveOnDeath);
	HookConVarChange(g_hRemoveOnDeath, OnConVarChange);
	
	AutoExecConfig(true, "shop_equipments", "shop");
	
	StartPlugin();
}

public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == g_hPreview)
	{
		g_bPreview = bool:StringToInt(newValue);
	}
	else if (convar == g_hRemoveOnDeath)
	{
		g_bRemoveOnDeath = bool:StringToInt(newValue);
	}
}

StartPlugin()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			OnClientConnected(i);
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
	
	if (Shop_IsStarted()) Shop_Started();
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
	for (new i = 1; i <= MaxClients; i++)
	{
		OnClientDisconnect(i);
	}
}

public Shop_Started()
{
	if (kv != INVALID_HANDLE)
	{
		CloseHandle(kv);
	}
	
	kv = CreateKeyValues("Equipments");
	
	decl String:_buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(_buffer, sizeof(_buffer), "equipments.txt");
	
	if (!FileToKeyValues(kv, _buffer))
	{
		SetFailState("Couldn't parse file %s", _buffer);
	}
	
	ClearArray(hCategories);
	
	decl String:lang[3], String:phrase[64];
	GetLanguageInfo(GetServerLanguage(), lang, sizeof(lang));
	
	if (KvGotoFirstSubKey(kv))
	{
		decl String:item[64], String:model[PLATFORM_MAX_PATH];
		do 
		{
			KvGetSectionName(kv, _buffer, sizeof(_buffer));
			if (!_buffer[0]) continue;
			
			if (FindStringInArray(hCategories, _buffer) == -1)
			{
				PushArrayString(hCategories, _buffer);
			}
			
			KvGetString(kv, lang, phrase, sizeof(phrase), "LangError");
			new CategoryId:category_id = Shop_RegisterCategory(_buffer, phrase, "", OnCategoryDisplay);
			
			decl symbol;
			KvGetSectionSymbol(kv, symbol);
			if (KvGotoFirstSubKey(kv))
			{
				do 
				{
					if (KvGetSectionName(kv, item, sizeof(item)))
					{
						KvGetString(kv, "model", model, sizeof(model));
						new pos = FindCharInString(model, '.', true);
						if (pos != -1 && StrEqual(model[pos+1], "mdl", false) && Shop_StartItem(category_id, item))
						{
							PrecacheModel(model, true);
							
							KvGetString(kv, "name", _buffer, sizeof(_buffer), item);
							Shop_SetInfo(_buffer, "", KvGetNum(kv, "price", 5000), KvGetNum(kv, "sell_price", 2500), Item_Togglable, KvGetNum(kv, "duration", 86400), KvGetNum(kv, "gold_price", 5000), KvGetNum(kv, "gold_sell_price", 2500));
							Shop_SetCallbacks(_, OnEquipItem);
							
							KvJumpToKey(kv, "Attributes", true);
							Shop_KvCopySubKeysCustomInfo(view_as<KeyValues>(kv));
							KvGoBack(kv);
							
							Shop_EndItem();
						}
					}
				}
				while (KvGotoNextKey(kv));
				
				KvRewind(kv);
				KvJumpToKeySymbol(kv, symbol);
			}
		}
		while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
}

public bool:OnCategoryDisplay(client, CategoryId:category_id, const String:category[], const String:name[], String:buffer[], maxlen)
{
	new bool:result = false;
	if (KvJumpToKey(kv, category))
	{
		KvGetString(kv, sClLang[client], buffer, maxlen, name);
		result = true;
	}
	KvRewind(kv);
	return result;
}

public Action:Command_Reload(client, args)
{
	OnPluginEnd();
	StartPlugin();
	OnMapStart();
	ReplyToCommand(client, "Equipments configuration successfuly reloaded!");
	return Plugin_Handled;
}

public OnMapStart()
{
	if (kv == INVALID_HANDLE)
	{
		return;
	}
	
	decl String:buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(buffer, sizeof(buffer), "equipments_downloads.txt");
	File_ReadDownloadList(buffer);
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			KvSavePosition(kv);
			if (KvGotoFirstSubKey(kv))
			{
				do 
				{
					KvGetString(kv, "model", buffer, sizeof(buffer));
					new pos = FindCharInString(buffer, '.', true);
					if (pos != -1 && StrEqual(buffer[pos+1], "mdl", false))
					{
						PrecacheModel(buffer, true);
					}
				} while (KvGotoNextKey(kv));
				
				KvGoBack(kv);
			}
		} while (KvGotoNextKey(kv));
	}
	
	KvRewind(kv);
}

public OnMapEnd()
{
	for (new i = 1; i <= MAXPLAYERS; i++)
	{
		hTimer[i] = INVALID_HANDLE;
	}
}

public OnClientConnected(client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	hTrieEntity[client] = CreateTrie();
	hTrieItem[client] = CreateTrie();
}

public OnClientPutInServer(client)
{
	//SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	GetLanguageInfo(GetClientLanguage(client), sClLang[client], sizeof(sClLang[]));
}

public OnClientDisconnect(client)
{
	ProcessDequip(client);
}

public OnClientDisconnect_Post(client)
{
	if (hTrieEntity[client] != INVALID_HANDLE)
	{
		CloseHandle(hTrieEntity[client]);
		hTrieEntity[client] = INVALID_HANDLE;
	}
	if (hTrieItem[client] != INVALID_HANDLE)
	{
		CloseHandle(hTrieItem[client]);
		hTrieItem[client] = INVALID_HANDLE;
	}
	if (hTimer[client] != INVALID_HANDLE)
	{
		KillTimer(hTimer[client]);
		hTimer[client] = INVALID_HANDLE;
	}
}

/*public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype, weapon, const Float:damageForce[3], const Float:damagePosition[3])
{
	if (!IsFakeClient(victim) && GetClientHealth(victim)-damage < 1)
	{
		if (!g_bRemoveOnDeath)
		{
			decl String:category[64], String:sModel[PLATFORM_MAX_PATH];
			for (new i = 0; i < GetArraySize(hCategories); i++)
			{
				GetArrayString(hCategories, i, category, sizeof(category));
				
				new ref = -1;
				if (!GetTrieValue(hTrieEntity[victim], category, ref))
				{
					continue;
				}
				
				new entity = EntRefToEntIndex(ref);
				if (entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
				{
					GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
					
					decl Float:fPos[3];
					GetClientEyePosition(victim, fPos);
					fPos[2] += 100.0;
					
					new ent = CreateEntityByName("prop_physics");
					SetEntProp(ent, Prop_Data, "m_CollisionGroup", 2);
					SetEntityModel(ent, sModel);
					DispatchSpawn(ent);
					
					TeleportEntity(ent, fPos, NULL_VECTOR, damageForce);
				}
			}
		}
		ProcessDequip(victim);
	}
}*/

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (hTrieEntity[client] == INVALID_HANDLE)
	{
		return;
	}
	if (!g_bRemoveOnDeath)
	{
		decl String:category[64], String:sModel[PLATFORM_MAX_PATH];
		for (new i = 0; i < GetArraySize(hCategories); i++)
		{
			GetArrayString(hCategories, i, category, sizeof(category));
			
			new ref = -1;
			if (!GetTrieValue(hTrieEntity[client], category, ref))
			{
				continue;
			}
			
			new entity = EntRefToEntIndex(ref);
			if (entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
			{
				GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
				
				decl Float:fPos[3];
				GetClientEyePosition(client, fPos);
				
				new ent = CreateEntityByName("prop_physics");
				if (ent != -1)
				{
					SetEntProp(ent, Prop_Data, "m_CollisionGroup", 2);
					SetEntityModel(ent, sModel);
					
					if (!DispatchSpawn(ent))
					{
						PrintToChatAll("Could not spawn %s", sModel);
					}
				}
				
				TeleportEntity(ent, fPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	ProcessDequip(client);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	CreateTimer(0.1, SpawnTimer, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:SpawnTimer(Handle:timer, any:userid)
{
	static dum[MAXPLAYERS+1];
	
	new client = GetClientOfUserId(userid);
	if (!client || hTrieEntity[client] == INVALID_HANDLE || IsFakeClient(client))
	{
		dum[client] = 0;
		return Plugin_Stop;
	}
	
	new size = GetArraySize(hCategories);
	if (!size || dum[client] >= size)
	{
		dum[client] = 0;
		return Plugin_Stop;
	}
	
	decl String:category[64];
	GetArrayString(hCategories, dum[client]++, category, sizeof(category));
	Equip(client, category);
	
	return Plugin_Continue;
}

public ShopAction:OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		Dequip(client, category);
		RemoveFromTrie(hTrieItem[client], category);
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	SetTrieString(hTrieItem[client], category, item);
	if (!Equip(client, category, true))
	{
		return Shop_UseOff;
	}
	
	return Shop_UseOn;
}

public Action:SetBackMode(Handle:timer, any:client)
{
	Client_SetThirdPersonMode(client, false);
	hTimer[client] = INVALID_HANDLE;
}

bool:Equip(client, const String:category[], bool:from_select = false)
{
	if (!IsPlayerAlive(client))
	{
		return true;
	}
	
	Dequip(client, category);
	
	decl String:item[64];
	if (!GetTrieString(hTrieItem[client], category, item, sizeof(item)))
	{
		return false;
	}

	decl Float:fAng[3], Float:fPos[3];

	decl String:entModel[PLATFORM_MAX_PATH], String:attachment[32], String:alt_attachment[32];
	entModel[0] = '\0';
	
	KvRewind(kv);
	if (KvJumpToKey(kv, category) && KvJumpToKey(kv, item))
	{
		KvGetString(kv, "model", entModel, sizeof(entModel));
		if (!entModel[0])
		{
			KvRewind(kv);
			return false;
		}
		
		decl String:buffer[PLATFORM_MAX_PATH];
		GetClientModel(client, buffer, sizeof(buffer));
		ReplaceString(buffer, sizeof(buffer), "/", "\\");
		if (KvJumpToKey(kv, "classes"))
		{
			if (KvJumpToKey(kv, buffer, false))
			{
				KvGetString(kv, "attachment", attachment, sizeof(attachment), "forward");
				KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
				KvGetVector(kv, "position", fPos);
				KvGetVector(kv, "angles", fAng);
			}
			else
			{
				KvGoBack(kv);
				KvGetString(kv, "attachment", attachment, sizeof(attachment), "forward");
				KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
				KvGetVector(kv, "position", fPos);
				KvGetVector(kv, "angles", fAng);
			}
		}
		else
		{
			KvGetString(kv, "attachment", attachment, sizeof(attachment), "forward");
			KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
			KvGetVector(kv, "position", fPos);
			KvGetVector(kv, "angles", fAng);
		}
	
		if (attachment[0])
		{
			if (!LookupAttachment(client, attachment))
			{
				if (alt_attachment[0])
				{
					if (!LookupAttachment(client, alt_attachment))
					{
						PrintToChat(client, "\x04[Shop] \x01Your current model is not supported. Reason: \x04Neither attachment \"\x03%s\x04\" nor \"\x03%s\x04\" is exists on your model (%s)", attachment, alt_attachment, buffer);
						KvRewind(kv);
						return false;
					}
					strcopy(attachment, sizeof(attachment), alt_attachment);
				}
				else
				{
					PrintToChat(client, "\x04[Shop] \x01Your current model is not supported. Reason: \x04Attachment \"\x03%s\x04\" is not exists on your model (%s)", attachment, buffer);
					return false;
				}
			}
		}
	}
	KvRewind(kv);

	decl Float:or[3], Float:ang[3],
		Float:fForward[3],
		Float:fRight[3],
	Float:fUp[3];
	
	GetClientAbsOrigin(client, or);
	GetClientAbsAngles(client, ang);

	ang[0] += fAng[0];
	ang[1] += fAng[1];
	ang[2] += fAng[2];
	
	GetAngleVectors(ang, fForward, fRight, fUp);

	or[0] += fRight[0]*fPos[0] + fForward[0]*fPos[1] + fUp[0]*fPos[2];
	or[1] += fRight[1]*fPos[0] + fForward[1]*fPos[1] + fUp[1]*fPos[2];
	or[2] += fRight[2]*fPos[0] + fForward[2]*fPos[1] + fUp[2]*fPos[2];

	new ent = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(ent, "model", entModel);
	DispatchKeyValue(ent, "spawnflags", "256");
	DispatchKeyValue(ent, "solid", "0");
	
	// We give the name for our entities here
	decl String:tName[24];
	Format(tName, sizeof(tName), "shop_equip_%d", ent);
	DispatchKeyValue(ent, "targetname", tName);
	
	DispatchSpawn(ent);	
	AcceptEntityInput(ent, "TurnOn", ent, ent, 0);
	
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	SetTrieValue(hTrieEntity[client], category, EntIndexToEntRef(ent), true);
	
	SDKHook(ent, SDKHook_SetTransmit, ShouldHide);
	
	TeleportEntity(ent, or, ang, NULL_VECTOR); 
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent, 0);
	
	if (attachment[0])
	{
		SetVariantString(attachment);
		AcceptEntityInput(ent, "SetParentAttachmentMaintainOffset", ent, ent, 0);
	}
	
	if (from_select && g_bPreview)
	{
		if (hTimer[client] != INVALID_HANDLE)
		{
			KillTimer(hTimer[client]);
			hTimer[client] = INVALID_HANDLE;
		}
		
		hTimer[client] = CreateTimer(1.0, SetBackMode, client, TIMER_FLAG_NO_MAPCHANGE);
		
		Client_SetThirdPersonMode(client, true);
	}
	
	return true;
}

ProcessDequip(client)
{
	if (hTrieEntity[client] == INVALID_HANDLE)
	{
		return;
	}
	
	decl String:category[64];
	for (new i = 0; i < GetArraySize(hCategories); i++)
	{
		GetArrayString(hCategories, i, category, sizeof(category));
		Dequip(client, category);
	}
}

Dequip(client, const String:category[])
{  
	new ref = -1;
	if (!GetTrieValue(hTrieEntity[client], category, ref))
	{
		return;
	}
	new entity = EntRefToEntIndex(ref);
	if (entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
	
	RemoveFromTrie(hTrieEntity[client], category);
}

public Action:ShouldHide(ent, client)
{
	if (Client_IsInThirdPersonMode(client) && IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	new owner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	if (owner == client)
	{
		return Plugin_Handled;
	}

	if (GetEntProp(client, Prop_Send, "m_iObserverMode") == 4)
	{
		if (owner == GetEntPropEnt(client, Prop_Send, "m_hObserverTarget"))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock bool:LookupAttachment(client, const String:point[])
{
    if (g_hLookupAttachment==INVALID_HANDLE) return false;
    if (client < 1 || !IsClientInGame(client)) return false;
	
    return SDKCall(g_hLookupAttachment, client, point);
}

new String:_smlib_empty_twodimstring_array[][] = { { '\0' } };
stock File_AddToDownloadsTable(const String:path[], bool:recursive=true, const String:ignoreExts[][]=_smlib_empty_twodimstring_array, size=0)
{
	if (path[0] == '\0') {
		return;
	}

	if (FileExists(path)) {
		
		decl String:fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));
		
		if (StrEqual(fileExtension, "bz2", false) || StrEqual(fileExtension, "ztmp", false)) {
			return;
		}
		
		if (Array_FindString(ignoreExts, size, fileExtension) != -1) {
			return;
		}

		AddFileToDownloadsTable(path);
		
		if (StrEqual(fileExtension, "mdl", false))
		{
			PrecacheModel(path, true);
		}
	}
	
	else if (recursive && DirExists(path)) {

		decl String:dirEntry[PLATFORM_MAX_PATH];
		new Handle:__dir = OpenDirectory(path);

		while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
				continue;
			}
			
			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);
			File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
		}
		
		CloseHandle(__dir);
	}
	else if (FindCharInString(path, '*', true)) {
		
		new String:fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));

		if (StrEqual(fileExtension, "*")) {

			decl
				String:dirName[PLATFORM_MAX_PATH],
				String:fileName[PLATFORM_MAX_PATH],
				String:dirEntry[PLATFORM_MAX_PATH];

			File_GetDirName(path, dirName, sizeof(dirName));
			File_GetFileName(path, fileName, sizeof(fileName));
			StrCat(fileName, sizeof(fileName), ".");

			new Handle:__dir = OpenDirectory(dirName);
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

stock bool:File_ReadDownloadList(const String:path[])
{
	new Handle:file = OpenFile(path, "r");
	
	if (file  == INVALID_HANDLE) {
		return false;
	}

	new String:buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) {
		ReadFileLine(file, buffer, sizeof(buffer));
		
		new pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) {
			buffer[pos] = '\0';
		}
		
		pos = StrContains(buffer, "#");
		if (pos != -1) {
			buffer[pos] = '\0';
		}

		pos = StrContains(buffer, ";");
		if (pos != -1) {
			buffer[pos] = '\0';
		}
		
		TrimString(buffer);
		
		if (buffer[0] == '\0') {
			continue;
		}

		File_AddToDownloadsTable(buffer);
	}

	CloseHandle(file);
	
	return true;
}

stock File_GetExtension(const String:path[], String:buffer[], size)
{
	new extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock Math_GetRandomInt(min, max)
{
	new random = GetURandomInt();
	
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock Array_FindString(const String:array[][], size, const String:str[], bool:caseSensitive=true, start=0)
{
	if (start < 0) {
		start = 0;
	}

	for (new i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) {
			return i;
		}
	}
	
	return -1;
}

stock bool:File_GetFileName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	new pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) {
		buffer[pos_ext] = '\0';
	}
}

stock bool:File_GetDirName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	new pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
		
		if (pos_start == -1) {
			buffer[0] = '\0';
			return;
		}
	}
	
	strcopy(buffer, size, path);
	buffer[pos_start] = '\0';
}

stock bool:File_GetBaseName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	new pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
	}
	
	pos_start++;
	
	strcopy(buffer, size, path[pos_start]);
}



// Spectator Movement modes
enum Obs_Mode
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};

enum Obs_Allow
{
	OBS_ALLOW_ALL = 0,	// allow all modes, all targets
	OBS_ALLOW_TEAM,		// allow only own team & first person, no PIP
	OBS_ALLOW_NONE,		// don't allow any spectating after death (fixed & fade to black)

	OBS_ALLOW_NUM_MODES,
};

stock Obs_Mode:Client_GetObserverMode(client)
{
	return Obs_Mode:GetEntProp(client, Prop_Send, "m_iObserverMode");
}

stock bool:Client_SetObserverMode(client, Obs_Mode:mode, bool:updateMoveType=true)
{
	if (mode < OBS_MODE_NONE || mode >= NUM_OBSERVER_MODES) {
		return false;
	}
	
	// check mp_forcecamera settings for dead players
	if (mode > OBS_MODE_FIXED && GetClientTeam(client) > 1)
	{
		new Handle:mp_forcecamera = FindConVar("mp_forcecamera");

		if (mp_forcecamera != INVALID_HANDLE) {
			switch (GetConVarInt(mp_forcecamera))
			{
				case OBS_ALLOW_TEAM: {
					mode = OBS_MODE_IN_EYE;
				}
				case OBS_ALLOW_NONE: {
					mode = OBS_MODE_FIXED; // don't allow anything
				}
			}
		}
	}

	new Obs_Mode:observerMode = Client_GetObserverMode(client);
	if (observerMode > OBS_MODE_DEATHCAM) {
		// remember mode if we were really spectating before
		Client_SetObserverLastMode(client, observerMode);
	}

	SetEntProp(client, Prop_Send, "m_iObserverMode", _:mode);

	switch (mode) {
		case OBS_MODE_NONE, OBS_MODE_FIXED, OBS_MODE_DEATHCAM: {
			Client_SetFOV(client, 0);	// Reset FOV
			
			if (updateMoveType) {
				SetEntityMoveType(client, MOVETYPE_NONE);
			}
		}
		case OBS_MODE_CHASE, OBS_MODE_IN_EYE: {
			// udpate FOV and viewmodels
			Client_SetViewOffset(client, NULL_VECTOR);
			
			if (updateMoveType) {
				SetEntityMoveType(client, MOVETYPE_OBSERVER);
			}
		}
		case OBS_MODE_ROAMING: {
			Client_SetFOV(client, 0);	// Reset FOV
			Client_SetViewOffset(client, NULL_VECTOR);
			
			if (updateMoveType) {
				SetEntityMoveType(client, MOVETYPE_OBSERVER);
			}
		}
	}

	return true;
}

stock Obs_mode:Client_GetObserverLastMode(client)
{
	return Obs_mode:GetEntProp(client, Prop_Data, "m_iObserverLastMode");
}

stock Client_SetObserverLastMode(client, Obs_Mode:mode)
{
	SetEntProp(client, Prop_Data, "m_iObserverLastMode", _:mode);
}

stock Client_GetViewOffset(client, Float:vec[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecViewOffset", vec);
}

stock Client_SetViewOffset(client, Float:vec[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecViewOffset", vec);
}

stock Client_GetObserverTarget(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
}

stock Client_SetObserverTarget(client, entity, bool:resetFOV=true)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", entity);
	
	if (resetFOV) {
		Client_SetFOV(client, 0);
	}
}

stock Client_GetFOV(client)
{
	return GetEntProp(client, Prop_Send, "m_iFOV");
}

stock Client_SetFOV(client, value)
{
	SetEntProp(client, Prop_Send, "m_iFOV", value);
}

stock bool:Client_DrawViewModel(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_bDrawViewmodel");
}

stock Client_SetDrawViewModel(client, bool:drawViewModel)
{
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", drawViewModel);
}

stock Client_SetThirdPersonMode(client, enable=true)
{
	if (enable) {
		Client_SetObserverTarget(client, 0);
		Client_SetObserverMode(client, OBS_MODE_DEATHCAM, false);
		Client_SetDrawViewModel(client, false);
		Client_SetFOV(client, 120);
	}
	else {
		Client_SetObserverTarget(client, -1);
		Client_SetObserverMode(client, OBS_MODE_NONE, false);
		Client_SetDrawViewModel(client, true);
		Client_SetFOV(client, 90);
	}
}

stock Client_IsInThirdPersonMode(client)
{
	return GetEntProp(client, Prop_Data, "m_iObserverMode");
}