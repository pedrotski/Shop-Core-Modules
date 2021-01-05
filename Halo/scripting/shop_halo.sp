#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>
#include <shop>

int g_iClientColor[MAXPLAYERS+1][4],
	g_BeamSprite,
	g_HaloSprite;

bool g_bHasAura[MAXPLAYERS+1],
	bEnableInvis;
Handle g_hKeyValues,
	g_hTimer[MAXPLAYERS+1];
	
#define pl(%0) for(int %0 = 1; %0 <= MaxClients; ++%0) if(IsClientInGame(%0))

public Plugin myinfo =
{
	name = "[Shop] Halo",
	author = "R1KO, ( rewritten Nek.'a 2x2 | ggwp.site )",
	version = "1.3.1"
};

public void OnPluginStart()
{
	ConVar cvar;
	cvar = CreateConVar("sm_shop_halo_invise", "1", "1 Enable only for your team, 0 display for all", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enable);
	bEnableInvis = cvar.BoolValue;
	AutoExecConfig(true, "halo_black", "shop");
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);

	if (Shop_IsStarted()) Shop_Started();
}

public void OnMapStart() 
{
	g_BeamSprite = PrecacheModel("materials/sprites/blueflare1.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/glow08.vmt");

	char buffer[PLATFORM_MAX_PATH];
	if (g_hKeyValues != INVALID_HANDLE) CloseHandle(g_hKeyValues);
	
	g_hKeyValues = CreateKeyValues("Halo_Colors");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "halo_colors.txt");
	
	if (!FileToKeyValues(g_hKeyValues, buffer)) SetFailState("Couldn't parse file %s", buffer);
}

public void CVarChanged_Enable(ConVar CVar, const char[] oldValue, const char[] newValue){bEnableInvis = CVar.BoolValue;}

public void OnPluginEnd(){Shop_UnregisterMe();}

public void Shop_Started()
{
	if (g_hKeyValues == INVALID_HANDLE) OnMapStart();

	KvRewind(g_hKeyValues);
	char sName[64], sDescription[64];
	
	KvGetString(g_hKeyValues, "name", sName, sizeof(sName), "Halo");
	KvGetString(g_hKeyValues, "description", sDescription, sizeof(sDescription));

	CategoryId category_id = Shop_RegisterCategory("halo", sName, sDescription);

	KvRewind(g_hKeyValues);

	if (KvGotoFirstSubKey(g_hKeyValues))
	{
		do
		{
			if (KvGetSectionName(g_hKeyValues, sName, sizeof(sName)) && Shop_StartItem(category_id, sName))
			{
				KvGetString(g_hKeyValues, "name", sDescription, sizeof(sDescription), sName);
				Shop_SetInfo(sDescription, "", KvGetNum(g_hKeyValues, "price", -1), KvGetNum(g_hKeyValues, "sellprice", -1), Item_Togglable, KvGetNum(g_hKeyValues, "duration", 604800));
				Shop_SetCallbacks(_, OnEquipItem);
				Shop_EndItem();
			}
		} while (KvGotoNextKey(g_hKeyValues));
	}
	
	KvRewind(g_hKeyValues);
}

public ShopAction OnEquipItem(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] sItem, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		OnClientDisconnect(iClient);
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(iClient, category_id);

	if (KvJumpToKey(g_hKeyValues, sItem, false))
	{
		int iColor[4];
		KvGetColor(g_hKeyValues, "color", iColor[0], iColor[1], iColor[2], iColor[3]);
		KvRewind(g_hKeyValues);

		for(int i=0; i < 4; i++) g_iClientColor[iClient][i] = iColor[i];
		
		g_bHasAura[iClient] = true;
		SetClientAura(iClient);
		
		return Shop_UseOn;
	}
	
	PrintToChat(iClient, "Failed to use \"%s\"!.", sItem);
	
	return Shop_Raw;
}

public void OnClientDisconnect(int iClient) 
{
	g_bHasAura[iClient] = false;
	if(g_hTimer[iClient] != INVALID_HANDLE)
	{
		KillTimer(g_hTimer[iClient]);
		g_hTimer[iClient] = INVALID_HANDLE;
	}
}

public void OnClientPostAdminCheck(int iClient){g_bHasAura[iClient] = false;}

public void Event_OnPlayerSpawn(Handle hEvent, const char[] sName, bool bSilent)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient > 0 && g_bHasAura[iClient] && IsPlayerAlive(iClient)) SetClientAura(iClient);
}

stock void SetClientAura(int iClient)
{
	if(g_hTimer[iClient] == INVALID_HANDLE) g_hTimer[iClient] = CreateTimer(0.1, Timer_Beacon, iClient, TIMER_REPEAT);
}

public Action Timer_Beacon(Handle hTimer, any iClient)
{
	if(IsClientInGame(iClient) && IsPlayerAlive(iClient) && g_bHasAura[iClient])
	{
		static float fVec[3];
		GetClientAbsOrigin(iClient, fVec);
		fVec[2] += 85;
		TE_SetupBeamRingPoint(fVec, 15.0, 17.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.1, 10.0, 5.0, g_iClientColor[iClient], 10, 0);
		if(!bEnableInvis) TE_SendToAll();
		else
		{
			int iTeam = GetClientTeam(iClient);
			TE_SendTo(iTeam);
		}
		return Plugin_Continue;
	} 
	else
	{
		KillTimer(g_hTimer[iClient]);
		g_hTimer[iClient] = INVALID_HANDLE;
	}
	return Plugin_Stop;
}

void TE_SendTo(int iTeam)
{
	int[] iClients = new int[MaxClients]; 
	int iGo;
    
	switch(!iGo)
    {
        case 1:
        {
            pl(ply)
            {
                if(GetClientTeam(ply) == iTeam) iClients[iGo++] = ply;
            }
        }
        case 2: pl(ply) iClients[iGo++] = ply;
    }
	if(iGo > 0) TE_Send(iClients, iGo);
}