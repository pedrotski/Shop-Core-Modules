#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>
#include <colors_csgo>
#pragma newdecls required

#define PLUGIN_VERSION	"2.1.1-A"

Handle g_hLookupAttachment = INVALID_HANDLE;

Handle kv;

Handle hTrieEntity[MAXPLAYERS+1];
Handle hTrieItem[MAXPLAYERS+1];
Handle hTimer[MAXPLAYERS+1];
char sClLang[MAXPLAYERS+1][3];
char ClientCategory[MAXPLAYERS+1];

float g_fScale[MAXPLAYERS+1];

Handle hCategories;

ConVar g_hPreview, g_hRemoveOnDeath, g_hDelay;
float g_fDelay;
bool g_bPreview;
bool g_bRemoveOnDeath;
Handle g_hOnLookStartPre;
Handle g_hOnLookStartPost;
Handle g_hOnLookEnd;

public Plugin myinfo =
{
    name        = "[Shop] Equipments",
    author      = "FrozDark, modify by BaFeR, Anubis Edition",
    description = "Equipments component for shop",
    version     = PLUGIN_VERSION,
    url         = "www.hlmod.ru"
}

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("shop_equipments.gamedata");
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
	g_hPreview.AddChangeHook(OnConVarChange);
	
	g_hOnLookStartPre  = CreateForward(ET_Event,  Param_Cell);
	g_hOnLookStartPost = CreateForward(ET_Ignore, Param_Cell);
	g_hOnLookEnd	   = CreateForward(ET_Ignore, Param_Cell);
	
	g_hRemoveOnDeath = CreateConVar("sm_shop_equipments_remove_on_death", "1", "Removes a player's equipments on death");
	g_bRemoveOnDeath = GetConVarBool(g_hRemoveOnDeath);
	g_hRemoveOnDeath.AddChangeHook(OnConVarChange);
	
	g_hDelay = CreateConVar("sm_shop_equipments_delay", "1.0", "Delay before set spawn.");
	g_fDelay = GetConVarFloat(g_hDelay);
	g_hDelay.AddChangeHook(OnConVarChange);
	AutoExecConfig(true, "shop_equipments", "shop");
	
	StartPlugin();
}

public void OnConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_hPreview)
	{
		g_bPreview = g_hPreview.BoolValue;
	}
	else if (convar == g_hRemoveOnDeath)
	{
		g_bRemoveOnDeath = g_hRemoveOnDeath.BoolValue;
	}
	else if (convar == g_hDelay)
	{
		g_fDelay = g_hDelay.FloatValue;
	}
}

public void StartPlugin()
{
	for (int i = 1; i <= MaxClients; i++)
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

public void OnPluginEnd()
{
	Shop_UnregisterMe();
	for (int i = 1; i <= MaxClients; i++)
	{
		OnClientDisconnect(i);
	}
}

public void Shop_Started()
{
	if (kv != INVALID_HANDLE)
	{
		CloseHandle(kv);
	}
	
	kv = CreateKeyValues("Equipments");
	
	char _buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(_buffer, sizeof(_buffer), "equipments.txt");
	
	if (!FileToKeyValues(kv, _buffer))
	{
		SetFailState("Couldn't parse file %s", _buffer);
	}
	
	ClearArray(hCategories);
	
	char lang[3], phrase[64];
	GetLanguageInfo(GetServerLanguage(), lang, sizeof(lang));
	
	if (KvGotoFirstSubKey(kv))
	{
		char item[64], model[PLATFORM_MAX_PATH];
		do 
		{
			KvGetSectionName(kv, _buffer, sizeof(_buffer));
			if (!_buffer[0]) continue;
			
			if (FindStringInArray(hCategories, _buffer) == -1)
			{
				PushArrayString(hCategories, _buffer);
			}
			
			KvGetString(kv, lang, phrase, sizeof(phrase), "LangError");
			CategoryId category_id = Shop_RegisterCategory(_buffer, phrase, "", OnCategoryDisplay);
			
			int symbol;
			KvGetSectionSymbol(kv, symbol);
			if (KvGotoFirstSubKey(kv))
			{
				do 
				{
					if (KvGetSectionName(kv, item, sizeof(item)))
					{
						KvGetString(kv, "model", model, sizeof(model));
						int pos = FindCharInString(model, '.', true);
						if (pos != -1 && StrEqual(model[pos+1], "mdl", false) && Shop_StartItem(category_id, item))
						{
							PrecacheModel(model, true);
							
							KvGetString(kv, "name", _buffer, sizeof(_buffer), item);
							Shop_SetInfo(_buffer, "", KvGetNum(kv, "price", 5000), KvGetNum(kv, "sell_price", 2500), Item_Togglable, KvGetNum(kv, "duration", 86400));
							
							if(g_hPreview)
								Shop_SetCallbacks(_, OnEquipItem, _, _, _, OnPreviewItem);
							else
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

public bool OnCategoryDisplay(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen, ShopMenu menu)
{
	bool result = false;
	if (KvJumpToKey(kv, category))
	{
		KvGetString(kv, sClLang[client], buffer, maxlen, name);
		result = true;
	}
	KvRewind(kv);
	return result;
}

public Action Command_Reload(int client, int args)
{
	OnPluginEnd();
	StartPlugin();
	OnMapStart();
	ReplyToCommand(client, "Equipments configuration successfuly reloaded!");
	return Plugin_Handled;
}

public void OnMapStart()
{
	PrecacheModel("models/error.mdl");
	LoadTranslations("shop_equipments_for_zr.phrases");

	if (kv == INVALID_HANDLE)
	{
		return;
	}
	
	char buffer[PLATFORM_MAX_PATH];
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
					int pos = FindCharInString(buffer, '.', true);
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

public void OnMapEnd()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		hTimer[i] = INVALID_HANDLE;
	}
}

public void OnClientConnected(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	hTrieEntity[client] = CreateTrie();
	hTrieItem[client] = CreateTrie();
}

public void OnClientPutInServer(int client)
{
	//SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	GetLanguageInfo(GetClientLanguage(client), sClLang[client], sizeof(sClLang[]));
}

public void OnClientDisconnect(int client)
{
	ProcessDequip(client);
}

public void OnClientDisconnect_Post(int client)
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

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (hTrieEntity[client] == INVALID_HANDLE)
	{
		return;
	}
	if (!g_bRemoveOnDeath)
	{
		char category[64], sModel[PLATFORM_MAX_PATH];
		for (int i = 0; i < GetArraySize(hCategories); i++)
		{
			GetArrayString(hCategories, i, category, sizeof(category));
			
			int ref = -1;
			if (!GetTrieValue(hTrieEntity[client], category, ref))
			{
				continue;
			}
			
			int entity = EntRefToEntIndex(ref);
			if (entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
			{
				GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
				
				float fPos[3];
				GetClientEyePosition(client, fPos);
				
				int ent = CreateEntityByName("prop_physics");
				if (ent != -1)
				{
					SetEntProp(ent, Prop_Data, "m_CollisionGroup", 2);
					SetEntityModel(ent, sModel);
					
					if (!DispatchSpawn(ent))
					{
						CPrintToChatAll("%t", "Could not spawn", sModel);
					}
				}
				
				TeleportEntity(ent, fPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	ProcessDequip(client);
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	ProcessDequip(client);
	Process(client);
	return Plugin_Continue;
}

public Action ZR_OnClientHuman(int &client, bool &respawn, bool &protect)
{
	ProcessDequip(client);
	Process(client);
	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	Process(client);
}

public Action Process(int client)
{
	CreateTimer(g_fDelay, ZrSpawnTimer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action ZrSpawnTimer(Handle timer, any client)
{
	static int dum[MAXPLAYERS+1];
	
	//int client = GetClientOfUserId(userid);
	if (!client || hTrieEntity[client] == INVALID_HANDLE || IsFakeClient(client))
	{
		dum[client] = 0;
		return Plugin_Stop;
	}
	
	int size = GetArraySize(hCategories);
	if (!size || dum[client] >= size)
	{
		dum[client] = 0;
		return Plugin_Stop;
	}
	
	char category[64];
	GetArrayString(hCategories, dum[client]++, category, sizeof(category));
	Equip(client, category);
	
	return Plugin_Continue;
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
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

public void OnPreviewItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsPlayerAlive(client))
		{
			Dequip(client, category);
			
			float fAng[3], fPos[3];

			char entModel[PLATFORM_MAX_PATH], attachment[32], alt_attachment[32];
			entModel[0] = '\0';
			
			KvRewind(kv);
			if (KvJumpToKey(kv, category) && KvJumpToKey(kv, item))
			{
				KvGetString(kv, "model", entModel, sizeof(entModel));
				if (!entModel[0])
				{
					KvRewind(kv);
					return;
				}
				
				char buffer[PLATFORM_MAX_PATH];
				GetClientModel(client, buffer, sizeof(buffer));
				ReplaceString(buffer, sizeof(buffer), "/", "\\");
				if (KvJumpToKey(kv, "classes"))
				{
					if (KvJumpToKey(kv, buffer, false))
					{
						
						KvGetString(kv, "attachment", attachment, sizeof(attachment), "primary");
						KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
						KvGetVector(kv, "position", fPos);
						KvGetVector(kv, "angles", fAng);
						g_fScale[client] = KvGetFloat(kv, "scale", 1.0);
					}
					else
					{
						KvGoBack(kv);
						KvGetString(kv, "attachment", attachment, sizeof(attachment), "primary");
						KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
						KvGetVector(kv, "position", fPos);
						KvGetVector(kv, "angles", fAng);
						g_fScale[client] = KvGetFloat(kv, "scale", 1.0);
					}
				}
				else
				{
					KvGetString(kv, "attachment", attachment, sizeof(attachment), "primary");
					KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
					KvGetVector(kv, "position", fPos);
					KvGetVector(kv, "angles", fAng);
					g_fScale[client] = KvGetFloat(kv, "scale", 1.0);
				}
			
			}
			KvRewind(kv);

			float or[3], ang[3],
				fForward[3],
				fRight[3],
			fUp[3];
			
			GetClientAbsOrigin(client, or);
			GetClientAbsAngles(client, ang);

			ang[0] += fAng[0];
			ang[1] += fAng[1];
			ang[2] += fAng[2];
			
			GetAngleVectors(ang, fForward, fRight, fUp);

			or[0] += fRight[0]*fPos[0] + fForward[0]*fPos[1] + fUp[0]*fPos[2];
			or[1] += fRight[1]*fPos[0] + fForward[1]*fPos[1] + fUp[1]*fPos[2];
			or[2] += fRight[2]*fPos[0] + fForward[2]*fPos[1] + fUp[2]*fPos[2];

			int ent = CreateEntityByName("prop_dynamic_override");
			DispatchKeyValue(ent, "model", entModel);
			DispatchKeyValue(ent, "spawnflags", "256");
			DispatchKeyValue(ent, "solid", "0");
			
			// We give the name for our entities here
			char tName[24];
			Format(tName, sizeof(tName), "shop_equip_%d", ent);
			DispatchKeyValue(ent, "targetname", tName);
			
			DispatchSpawn(ent);	

			int iScaleOfsset = GetEntSendPropOffs(ent, "m_flModelScale", true);
			if(iScaleOfsset != -1)
			{
				SetEntDataFloat(ent, iScaleOfsset, g_fScale[client], true);
			}
			
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
		
			hTimer[client] = CreateTimer(3.0, SetBackMode_Preview, client, TIMER_FLAG_NO_MAPCHANGE);
			strcopy(ClientCategory[client], sizeof(ClientCategory), category);
			Client_SetThirdPersonMode(client, true);
		}
		else
			CPrintToChat(client, "%t", "You are dead");
	}
}

public Action SetBackMode_Preview(Handle timer, any client)
{
	Client_SetThirdPersonMode(client, false);
	Dequip(client, ClientCategory[client]);
	hTimer[client] = INVALID_HANDLE;
}

public Action SetBackMode(Handle timer, any client)
{
	Client_SetThirdPersonMode(client, false);
	hTimer[client] = INVALID_HANDLE;
}

bool Equip(int client, const char[] category, bool from_select = false)
{
	if (!IsPlayerAlive(client))
	{
		return true;
	}
	
	Dequip(client, category);
	
	char item[64];
	if (!GetTrieString(hTrieItem[client], category, item, sizeof(item)))
	{
		return false;
	}

	float fAng[3], fPos[3];

	char entModel[PLATFORM_MAX_PATH], attachment[32], alt_attachment[32];
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
		
		char buffer[PLATFORM_MAX_PATH];
		GetClientModel(client, buffer, sizeof(buffer));
		ReplaceString(buffer, sizeof(buffer), "/", "\\");
		if (KvJumpToKey(kv, "classes"))
		{
			if (KvJumpToKey(kv, buffer, false))
			{
				
				KvGetString(kv, "attachment", attachment, sizeof(attachment), "primary");
				KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
				KvGetVector(kv, "position", fPos);
				KvGetVector(kv, "angles", fAng);
				g_fScale[client] = KvGetFloat(kv, "scale", 1.0);
			}
			else
			{
				KvGoBack(kv);
				KvGetString(kv, "attachment", attachment, sizeof(attachment), "primary");
				KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
				KvGetVector(kv, "position", fPos);
				KvGetVector(kv, "angles", fAng);
				g_fScale[client] = KvGetFloat(kv, "scale", 1.0);
			}
		}
		else
		{
			KvGetString(kv, "attachment", attachment, sizeof(attachment), "primary");
			KvGetString(kv, "alt_attachment", alt_attachment, sizeof(alt_attachment), "");
			KvGetVector(kv, "position", fPos);
			KvGetVector(kv, "angles", fAng);
			g_fScale[client] = KvGetFloat(kv, "scale", 1.0);
		}
	
		if (attachment[0])
		{
			if (!LookupAttachment(client, attachment))
			{
				if (alt_attachment[0])
				{
					if (!LookupAttachment(client, alt_attachment))
					{
						CPrintToChat(client, "%t", "Your current model is not supported Neither attachment", attachment, alt_attachment, buffer);
						KvRewind(kv);
						return false;
					}
					strcopy(attachment, sizeof(attachment), alt_attachment);
				}
				else
				{
					CPrintToChat(client, "%t", "Your current model is not supported Attachment", attachment, buffer);
					return false;
				}
			}
		}
	}
	KvRewind(kv);

	float or[3], ang[3],
		fForward[3],
		fRight[3],
	fUp[3];
	
	GetClientAbsOrigin(client, or);
	GetClientAbsAngles(client, ang);

	ang[0] += fAng[0];
	ang[1] += fAng[1];
	ang[2] += fAng[2];
	
	GetAngleVectors(ang, fForward, fRight, fUp);

	or[0] += fRight[0]*fPos[0] + fForward[0]*fPos[1] + fUp[0]*fPos[2];
	or[1] += fRight[1]*fPos[0] + fForward[1]*fPos[1] + fUp[1]*fPos[2];
	or[2] += fRight[2]*fPos[0] + fForward[2]*fPos[1] + fUp[2]*fPos[2];

	int ent = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(ent, "model", entModel);
	DispatchKeyValue(ent, "spawnflags", "256");
	DispatchKeyValue(ent, "solid", "0");
	
	// We give the name for our entities here
	char tName[24];
	Format(tName, sizeof(tName), "shop_equip_%d", ent);
	DispatchKeyValue(ent, "targetname", tName);
	
	DispatchSpawn(ent);	

	int iScaleOfsset = GetEntSendPropOffs(ent, "m_flModelScale", true);
	if(iScaleOfsset != -1)
	{
		SetEntDataFloat(ent, iScaleOfsset, g_fScale[client], true);
	}
	
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

public void ProcessDequip(int client)
{
	if (hTrieEntity[client] == INVALID_HANDLE)
	{
		return;
	}
	
	char category[64];
	for (int i = 0; i < GetArraySize(hCategories); i++)
	{
		GetArrayString(hCategories, i, category, sizeof(category));
		Dequip(client, category);
	}
}

public void Dequip(int client, const char[] category)
{  
	int ref = -1;
	if (!GetTrieValue(hTrieEntity[client], category, ref))
	{
		return;
	}
	int entity = EntRefToEntIndex(ref);
	if (entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
	
	RemoveFromTrie(hTrieEntity[client], category);
}

public Action ShouldHide(int ent, int client)
{
	if (Client_IsInThirdPersonMode(client) && IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	int owner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
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

stock bool LookupAttachment(int client, const char[] point)
{
    if (g_hLookupAttachment==INVALID_HANDLE) return false;
    if (client < 1 || !IsClientInGame(client)) return false;
	
    return SDKCall(g_hLookupAttachment, client, point);
}



char _smlib_empty_twodimstring_array[][] = { { '\0' } };
stock void File_AddToDownloadsTable(char[] path, bool recursive = true, const char[][] ignoreExts = _smlib_empty_twodimstring_array, int size = 0)
{
	if (path[0] == '\0') {
		return;
	}

	if (FileExists(path)) {
		
		char fileExtension[4];
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

		char dirEntry[PLATFORM_MAX_PATH];
		Handle __dir = OpenDirectory(path);

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

stock bool File_ReadDownloadList(const char[] path)
{
	Handle file = OpenFile(path, "r");
	
	if (file  == INVALID_HANDLE) {
		return false;
	}

	char buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) {
		ReadFileLine(file, buffer, sizeof(buffer));
		
		int pos;
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
	if (start < 0) {
		start = 0;
	}

	for (int i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) {
			return i;
		}
	}
	
	return -1;
}

stock bool File_GetFileName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	int pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) {
		buffer[pos_ext] = '\0';
	}
}

stock bool File_GetDirName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
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

stock bool File_GetBaseName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
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

stock Obs_Mode Client_GetObserverMode(int client)
{
	return view_as<Obs_Mode>(GetEntProp(client, Prop_Send, "m_iObserverMode"));
}

stock bool Client_SetObserverMode(int client, Obs_Mode mode, bool updateMoveType=true)
{
	if (mode < OBS_MODE_NONE || mode >= NUM_OBSERVER_MODES) {
		return false;
	}
	
	// check mp_forcecamera settings for dead players
	if (mode > OBS_MODE_FIXED && GetClientTeam(client) > 1)
	{
		Handle mp_forcecamera = FindConVar("mp_forcecamera");

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

	Obs_Mode observerMode = Client_GetObserverMode(client);
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

stock Obs_Mode Client_GetObserverLastMode(int client)
{
	//return Obs_mode:GetEntProp(client, Prop_Data, "m_iObserverLastMode");
	return view_as<Obs_Mode>(GetEntProp(client, Prop_Data, "m_iObserverLastMode"));
}

stock void Client_SetObserverLastMode(int client, Obs_Mode mode)
{
	SetEntProp(client, Prop_Data, "m_iObserverLastMode", _:mode);
}

stock void Client_GetViewOffset(int client, float vec[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecViewOffset", vec);
}

stock void Client_SetViewOffset(int client, float vec[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecViewOffset", vec);
}

stock int Client_GetObserverTarget(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
}

stock void Client_SetObserverTarget(int client, int entity, bool resetFOV=true)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", entity);
	
	if (resetFOV) {
		Client_SetFOV(client, 0);
	}
}

stock int Client_GetFOV(int client)
{
	return GetEntProp(client, Prop_Send, "m_iFOV");
}

stock void Client_SetFOV(int client, int value)
{
	SetEntProp(client, Prop_Send, "m_iFOV", value);
}

stock bool Client_DrawViewModel(int client)
{
	return GetEntProp(client, Prop_Send, "m_bDrawViewmodel") != 0;
}

stock void Client_SetDrawViewModel(int client, bool drawViewModel)
{
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", drawViewModel);
}

stock void Client_SetThirdPersonMode(int client, bool enable=true)
{
	if (enable) 
	{
		Action result = Plugin_Continue;
		Call_StartForward(g_hOnLookStartPre);
		Call_PushCell(client);
		Call_Finish(result);
		if (result != Plugin_Continue)
			return;

		//
		
		int entity = CreateEntityByName("prop_dynamic");
		if (entity <= MaxClients)
			return;
		
		DispatchKeyValue(entity, "model", "models/error.mdl");
		DispatchKeyValue(entity, "solid", "0");
		//DispatchKeyValue(entity, "spawnflags", "256");
		
		float v[3];
		GetClientEyePosition(client, v);
		float a[3];
		GetClientAbsAngles(client, a);
		
		a[0] = 0.0;
		a[2] = 0.0;
		float direction[3];
		GetAngleVectors(a, direction, NULL_VECTOR, NULL_VECTOR);
		v[0] += direction[0] * 100.0;
		v[1] += direction[1] * 100.0;
		
		DispatchKeyValueVector(entity, "origin", v);
		a[1] += 180.0;
		DispatchKeyValueVector(entity, "angles", a);
		
		DispatchSpawn(entity);
		
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
		
		//
		
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(client, Prop_Send, "m_iFOV", 50);
		
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetClientViewEntity(client, entity);
		
		//
		
		Call_StartForward(g_hOnLookStartPost);
		Call_PushCell(client);
		Call_Finish();
	}
	else 
	{
		SetClientViewEntity(client, client);
		SetEntityMoveType(client, MOVETYPE_WALK);
			
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		
		Call_StartForward(g_hOnLookEnd);
		Call_PushCell(client);
		Call_Finish();
	}
}

stock bool Client_IsInThirdPersonMode(int client)
{
	return Client_GetObserverMode(client) == OBS_MODE_DEATHCAM;
}