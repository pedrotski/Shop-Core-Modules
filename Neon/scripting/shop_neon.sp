#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>

// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.3.0"

#define CATEGORY	"neon"

int g_iClientColor[MAXPLAYERS+1][4];
int g_iNeon[MAXPLAYERS+1];
KeyValues g_hKv;

public Plugin myinfo =
{
	name = "[Shop] Neon",
	author = "White Wolf (HLModders LLC)",
	description = "Adds neon to shop",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	CreateConVar("shop_neon_version", PLUGIN_VERSION, _, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	if (Shop_IsStarted()) Shop_Started();
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];
	if (g_hKv != null) g_hKv.Close();
	g_hKv = new KeyValues("Neon");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "neon.txt");
	
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
	g_hKv.GetString("name", cName, sizeof(cName), "Neon");
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
		OnClientDisconnect(client);
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	if (g_hKv.JumpToKey(cItem, false) && IsPlayerAlive(client))
	{
		int iColor[4];
		g_hKv.GetColor("color", iColor[0], iColor[1], iColor[2], iColor[3]);
		g_hKv.Rewind();
		
		for (int i = 0; i < 4; i++)
			g_iClientColor[client][i] = iColor[i];
		
		SetClientNeon(client);
		return Shop_UseOn;
	}
	
	PrintToChat(client, "\x01[\x03Shop\x01] \x01Не удалось активировать неон.");
	return Shop_Raw;
}

public void OnClientDisconnect(int client)
{
	RemoveClientNeon(client);
}

public void OnClientPostAdminCheck(int client)
{
	RemoveClientNeon(client);
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool silent)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && g_iNeon[client] && IsPlayerAlive(client))
		SetClientNeon(client);
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool silent)
{
	RemoveClientNeon(GetClientOfUserId(event.GetInt("userid")));
}

void RemoveClientNeon(int client)
{
	if (g_iNeon[client] > 0 && IsValidEdict(g_iNeon[client]))
		AcceptEntityInput(g_iNeon[client], "Kill");
}

void SetClientNeon(int client)
{
	RemoveClientNeon(client);
	float clientOrigin[3]; float pos[3]; float beampos[3]; float FurnitureOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	GetCollisionPoint(client, pos);
	FurnitureOrigin[0] = pos[0];
	FurnitureOrigin[1] = pos[1];
	FurnitureOrigin[1] = (pos[2] + 50);
	beampos[0] = pos[0];
	beampos[1] = pos[1];
	beampos[2] = (FurnitureOrigin[2] + 20);
	int Neon = CreateEntityByName("light_dynamic");
	DispatchKeyValue(Neon, "brightness", "5");
	char color[18];
	FormatEx(color, sizeof(color), "%d %d %d %d", g_iClientColor[client][0], g_iClientColor[client][1], g_iClientColor[client][2], g_iClientColor[client][3]);
	DispatchKeyValue(Neon, "_light", color);
	DispatchKeyValue(Neon, "spotlight_radius", "50");
	DispatchKeyValue(Neon, "distance", "150");
	DispatchKeyValue(Neon, "style", "0");
	FormatEx(color, sizeof(color), "shop_neon_%d", Neon);
	DispatchKeyValue(Neon, "targetname", color);
	SetEntPropEnt(Neon, Prop_Send, "m_hOwnerEntity", client);
	if (DispatchSpawn(Neon))
	{
		AcceptEntityInput(Neon, "TurnOn");
		g_iNeon[client] = Neon;
		TeleportEntity(Neon, clientOrigin, NULL_VECTOR, NULL_VECTOR);
		SetVariantString("!activator");
		AcceptEntityInput(Neon, "SetParent", client, Neon, 0);
	}
	else
		g_iNeon[client] = 0;
}

void GetCollisionPoint(int client, float pos[3])
{
	float vOrigin[3]; float vAngles[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		trace.Close();
		return;
	}
	trace.Close();
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients;
}