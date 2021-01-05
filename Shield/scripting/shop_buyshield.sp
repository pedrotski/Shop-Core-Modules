#pragma semicolon 1

#define PLUGIN_AUTHOR "MaZa"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <shop>

#pragma newdecls required

EngineVersion g_Game;

public Plugin myinfo = 
{
	name = "[SHOP] Shield", 
	author = PLUGIN_AUTHOR, 
	description = "Выдает щит", 
	version = PLUGIN_VERSION, 
	url = "vk.com/id156040107"
};


int m_hMyWeapons, 
m_iItemDefinitionIndex, 
mWeapon;
bool g_bHasShield[MAXPLAYERS + 1];
Handle g_hPrice, g_hSellPrice, g_hDuration;
ItemId id;

public void OnPluginStart()
{
	m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	m_iItemDefinitionIndex = FindSendPropInfo("CEconEntity", "m_iItemDefinitionIndex");
	
	AutoExecConfig(true, "shop_shield", "shop");
	
	g_hPrice = CreateConVar("sm_shop_shield_price", "1000", "Shield purchase cost.");
	HookConVarChange(g_hPrice, OnConVarChange);
	
	g_hSellPrice = CreateConVar("sm_shop_shield_sellprice", "800", "Shield selling price.");
	HookConVarChange(g_hPrice, OnConVarChange);
	
	g_hDuration = CreateConVar("sm_shop_shield_duration", "86400", "Shield duration in seconds.");
	HookConVarChange(g_hDuration, OnConVarChange);
	
	g_Game = GetEngineVersion();
	if (g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");
	}
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	if (Shop_IsStarted())Shop_Started();
}

public void OnPluginEnd()
{ Shop_UnregisterMe(); }
public void OnClientDisconnect(int iClient)
{ g_bHasShield[iClient] = false; }


public void OnConVarChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if (id != INVALID_ITEM)
	{
		if (hCvar == g_hPrice)Shop_SetItemPrice(id, GetConVarInt(hCvar));
		else if (hCvar == g_hSellPrice)Shop_SetItemSellPrice(id, GetConVarInt(hCvar));
		else if (hCvar == g_hDuration)Shop_SetItemValue(id, GetConVarInt(hCvar));
	}
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory("ability", "Abilities", "");
	
	if (Shop_StartItem(category_id, "shield"))
	{
		Shop_SetInfo("Щит", "", GetConVarInt(g_hPrice), GetConVarInt(g_hSellPrice), Item_Togglable, GetConVarInt(g_hDuration));
		Shop_SetCallbacks(OnItemRegistered, OnShieldUsed);
		Shop_EndItem();
	}
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{ id = item_id; }
public void Shop_OnAuthorized(int iClient)
{ g_bHasShield[iClient] = false; }

public ShopAction OnShieldUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (IsPlayerAlive(iClient) && !IsFakeClient(iClient))
		if (isOn || elapsed)
	{
		g_bHasShield[iClient] = false;
		int iWeapon = GetPlayerWeapon(iClient, "weapon_shield");
		if (iWeapon != -1)
		{
			if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == iWeapon)
			{
				FakeClientCommand(iClient, "use weapon_knife");
			}
			RemovePlayerItem(iClient, iWeapon) && AcceptEntityInput(iWeapon, "Kill");
		}
		return Shop_UseOff;
	}
	
	g_bHasShield[iClient] = true; SpawnShield(iClient);
	return Shop_UseOn;
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_bHasShield[iClient] == true)SpawnShield(iClient);
}

//Thank you gubka
void SpawnShield(int iClient)
{
	int iShield = CreateEntityByName("weapon_shield");
	if (iShield != -1)
	{
		DispatchSpawn(iShield);
		if (cWeapon(iClient, 37))
		{
			EquipPlayerWeapon(iClient, iShield);
		}
	}
}

bool cWeapon(int iClient, int iIndex)
{
	for (int i; i < 64; i++)
	{
		mWeapon = GetEntDataEnt2(iClient, m_hMyWeapons + i * 4);
		if (mWeapon != -1 && IsValidEntity(mWeapon))
		{
			if (GetEntData(mWeapon, m_iItemDefinitionIndex) == iIndex)
			{
				return false;
			}
		}
	}
	
	return true;
}

//Thank you gubka
stock int GetPlayerWeapon(int clientIndex, char[] sType)
{
	// Initialize name char
	static char sClassname[13];
	
	// i = weapon number
	static int iSize; if (!iSize)iSize = GetEntPropArraySize(clientIndex, Prop_Send, "m_hMyWeapons");
	for (int i = 0; i < iSize; i++)
	{
		// Gets weapon index
		int weaponIndex = GetEntPropEnt(clientIndex, Prop_Send, "m_hMyWeapons", i);
		
		// Validate weapon
		if (weaponIndex != -1 && IsValidEntity(weaponIndex))
		{
			// Gets weapon classname
			GetEdictClassname(weaponIndex, sClassname, sizeof(sClassname));
			
			// If weapon find, then return
			if (!strcmp(sClassname[7], sType[7], false))
			{
				return weaponIndex;
			}
		}
	}
	
	// Weapon wasn't found
	return -1;
} 