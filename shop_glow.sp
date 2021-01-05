#pragma semicolon 1
#include <sdktools>
#include <sdkhooks>
#include <shop>

// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.0.1"

#define CATEGORY "glow"

int g_iClientColor[MAXPLAYERS +1][4], g_iEntity[MAXPLAYERS +1];
bool g_bGlow[MAXPLAYERS +1];
KeyValues g_hKv;

public Plugin myinfo =
{
	name = "[Shop] Glow",
	author = "Drumanid (plugin  alteration | [Shop] Neon White Wolf (HLModders LLC))",
	description = "Adds glow to shop",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	CreateConVar("shop_glow_version", PLUGIN_VERSION, _, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	if (Shop_IsStarted()) Shop_Started();
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];
	if (g_hKv != null) g_hKv.Close();
	g_hKv = new KeyValues("Glow");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "glow.txt");
	
	if (!g_hKv.ImportFromFile(buffer)) SetFailState("Couldn't parse file %s", buffer);
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public int Shop_Started()
{
	if (g_hKv == null) OnMapStart();
	g_hKv.Rewind();
	char cName[80]; char cDescription[80];
	g_hKv.GetString("name", cName, sizeof(cName), "Glow");
	g_hKv.GetString("description", cDescription, sizeof(cDescription));
	
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, cName, cDescription);
	
	g_hKv.Rewind();
	
	if (g_hKv.GotoFirstSubKey(true))
	{
		do
		{
			if (g_hKv.GetSectionName(cName, sizeof(cName)) && Shop_StartItem(category_id, cName))
			{
				g_hKv.GetString("name", cName, sizeof(cName), cName);
				g_hKv.GetString("description", cDescription, sizeof(cDescription), "");
				Shop_SetInfo(cName, cDescription, g_hKv.GetNum("price", 1000), g_hKv.GetNum("sellprice", -1), Item_Togglable, g_hKv.GetNum("duration", 604800));
				Shop_SetCallbacks(_, OnEquipItem);
				Shop_EndItem();
			}
		} while (g_hKv.GotoNextKey(true));
	}
	g_hKv.Rewind();
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] cItem, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bGlow[client] = false;
		
		OnClientDisconnect(client);
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	if (g_hKv.JumpToKey(cItem, false))
	{
		g_bGlow[client] = true;
		
		g_hKv.GetColor("color", g_iClientColor[client][0], g_iClientColor[client][1], g_iClientColor[client][2], g_iClientColor[client][3]);
		g_hKv.Rewind();
		
		if(IsPlayerAlive(client)) SetGlow(client);
		return Shop_UseOn;
	}
	
	PrintToChat(client, "\x01[\x03Shop\x01] \x01Не удалось активировать свечение.");
	return Shop_Raw;
}

public void OnClientDisconnect(int client)
{
	RemoveModel(client);
}

public void OnClientPostAdminCheck(int client)
{
	g_bGlow[client] = false;
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool silent)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && g_bGlow[client] && IsPlayerAlive(client))
		SetGlow(client);
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool silent)
{
	RemoveModel(GetClientOfUserId(event.GetInt("userid")));
}

//https://forums.alliedmods.net/showthread.php?t=280484
void SetGlow(int client)
{
	char sBuffer[128];
	GetClientModel(client, sBuffer, sizeof(sBuffer));
	
	int iEntity = CreatePlayerModel(client, sBuffer);
	
	int iOffset = GetEntSendPropOffs(iEntity, "m_clrGlow");
	
	if(iOffset == -1)
	{
		LogError("Bad offset: \"m_clrGlow\"!");
		return;
	}
	
	SetEntProp(iEntity, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(iEntity, Prop_Send, "m_nGlowStyle", 1); // 0 - esp / 1,2 - glow
	SetEntPropFloat(iEntity, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	
	for(int i = 0; i < 4; i++) SetEntData(iEntity, iOffset + i, g_iClientColor[client][i], _, true);
}

int CreatePlayerModel(int client, const char[] sBuffer)
{
	RemoveModel(client);
	
	int iEntity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(iEntity, "model", sBuffer);
	DispatchKeyValue(iEntity, "solid", "0");
	DispatchSpawn(iEntity);
	
	SetEntityRenderMode(iEntity, RENDER_TRANSALPHA);
	SetEntityRenderColor(iEntity, 255, 255, 255, 0);
	
	SetEntProp(iEntity, Prop_Send, "m_fEffects", (1 << 0)|(1 << 4)|(1 << 6)|(1 << 9));
	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", client, iEntity, 0);
	SetVariantString("primary");
	AcceptEntityInput(iEntity, "SetParentAttachment", iEntity, iEntity, 0);
	
	g_iEntity[client] = EntIndexToEntRef(iEntity);
	return iEntity;
}

void RemoveModel(int client)
{
	int iEntity = EntRefToEntIndex(g_iEntity[client]);
	if(iEntity != INVALID_ENT_REFERENCE && iEntity > 0 && IsValidEntity(iEntity)) AcceptEntityInput(iEntity, "Kill");

	g_iEntity[client] = 0;
}