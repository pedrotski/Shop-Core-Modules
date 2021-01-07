#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <shop>

public Plugin myinfo =
{
	name = "[GCG] Sounds",
	author = "GhostCap Gaming",
	version = "1.0",
	url = "https://www.ghostcap.com"
};

KeyValues Kv;

CategoryId g_iCategory_id;

int g_iRoundUses,
	g_iMapUses,
	g_iCooldown,
	g_iCommonCooldown;

bool g_bCooldownKill;
	
int g_iRoundUsesCount[MAXPLAYERS+1],
	g_iMapUsesCount[MAXPLAYERS+1];

Handle g_hCooldownTimer[MAXPLAYERS+1],
		g_hCommonCooldownTimer,
		g_hSoundTimer;

EngineVersion g_eGameEngine = Engine_Unknown;

public void OnPluginStart()
{
	ConVar cCvar;
	
	cCvar = CreateConVar("sm_shop_sounds_cooldown", "30", "Time between uses for one player.");
	HookConVarChange(cCvar, OnCooldownChange);
	g_iCooldown = cCvar.IntValue;
	
	cCvar = CreateConVar("sm_shop_sounds_common_cooldown", "15", "Time between uses for all players.");
	HookConVarChange(cCvar, OnCommonCooldownChange);
	g_iCommonCooldown = cCvar.IntValue;
	
	cCvar = CreateConVar("sm_shop_sounds_cooldown_kill", "1", "Disabling the timer for use at the beginning of the round.");
	HookConVarChange(cCvar, OnCooldownKillChange);
	g_bCooldownKill = cCvar.BoolValue;
	
	cCvar = CreateConVar("sm_shop_sounds_round_uses", "3", "Number of uses per round.");
	HookConVarChange(cCvar, OnRoundUsesChange);
	g_iRoundUses = cCvar.IntValue;
	
	cCvar = CreateConVar("sm_shop_sounds_map_uses", "15", "Number of uses per map.");
	HookConVarChange(cCvar, OnMapUsesChange);
	g_iMapUses = cCvar.IntValue;
	
	HookEvent("round_start", Event_RoundStart);
	
	g_eGameEngine = GetEngineVersion();
	
	LoadTranslations("shop_sounds.phrases.txt");
	if (Shop_IsStarted()) Shop_Started();
}

public void OnCooldownChange(ConVar  cCvar, const char[] oldValue, const char[] newValue)
{
	g_iCooldown = cCvar.IntValue;
}

public void OnCommonCooldownChange(ConVar  cCvar, const char[] oldValue, const char[] newValue)
{
	g_iCommonCooldown = cCvar.IntValue;
}

public void OnRoundUsesChange(ConVar  cCvar, const char[] oldValue, const char[] newValue)
{
	g_iRoundUses = cCvar.IntValue;
}

public void OnMapUsesChange(ConVar  cCvar, const char[] oldValue, const char[] newValue)
{
	g_iMapUses = cCvar.IntValue;
}

public void OnCooldownKillChange(ConVar  cCvar, const char[] oldValue, const char[] newValue)
{
	g_bCooldownKill = cCvar.BoolValue;
}

public Action Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	for(int i; i <= MaxClients; i++)
	{
		g_iRoundUsesCount[i] = 0;
		if(g_bCooldownKill)
		{
			if(g_hCooldownTimer[i]) KillTimer(g_hCooldownTimer[i]); g_hCooldownTimer[i] = null;
		}
	}
	
	if(g_bCooldownKill)
	{
		if(g_hCommonCooldownTimer) KillTimer(g_hCommonCooldownTimer); g_hCommonCooldownTimer = null;
	}
	
	if(g_hSoundTimer) KillTimer(g_hSoundTimer); g_hSoundTimer = null;
}

public void OnClientDisconnect(int iClient)
{
	if(g_hCooldownTimer[iClient])	KillTimer(g_hCooldownTimer[iClient]); g_hCooldownTimer[iClient] = null;
	g_iRoundUsesCount[iClient] = 0;
	g_iMapUsesCount[iClient] = 0;
}

public void OnMapStart() 
{
	for(int i; i <= MaxClients; i++)
	{
		g_iRoundUsesCount[i] = 0;
		g_iMapUsesCount[i] = 0;
	}
	
	char cPath[192];
	char cFixPath[192];
	Handle filedownload = OpenFile("addons/sourcemod/configs/shop/sounds/downloads.txt", "r");
	
	if(filedownload == null)
    {
        LogError("Failed to load addons/sourcemod/configs/sounds/downloads.txt");
        SetFailState("Failed to load addons/sourcemod/configs/sounds/downloads.txt");
        return;
    }
	
	
	while(!IsEndOfFile(filedownload) && ReadFileLine(filedownload, cPath, 192))
    {
        TrimString(cPath);
        if (IsCharAlpha(cPath[0])) 
		{
			FormatEx(cFixPath, PLATFORM_MAX_PATH, "sound/%s", cPath);
			AddFileToDownloadsTable(cFixPath);
			if(g_eGameEngine == Engine_CSGO) 
			{
				FormatEx(cFixPath, PLATFORM_MAX_PATH, "*%s", cPath);
			}
			else strcopy(cFixPath, sizeof(cFixPath), cPath);
			
			PrecacheSound(cFixPath, true);
		}
    }
	delete(filedownload);
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void Shop_Started()
{
	Kv = new KeyValues("Sounds");
	g_iCategory_id = Shop_RegisterCategory("Sounds", "Sounds", "");
	
	char cBuffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(cBuffer, sizeof(cBuffer), "sounds.ini");
	if (!FileToKeyValues(Kv, cBuffer)) SetFailState("Configuration file not found %s", cBuffer);
	
	
	char cName[64], cDescription[64];
	Kv.Rewind();

	if (Kv.GotoFirstSubKey())
	{
		do
		{
			if (Kv.GetSectionName(cName, sizeof(cName)) && Shop_StartItem(g_iCategory_id, cName))
			{
				Kv.GetString("name", cName, sizeof(cName));
				Kv.GetString("description", cDescription, sizeof(cDescription), "");
				
				Shop_SetInfo(cName, cDescription, Kv.GetNum("price", 1000), Kv.GetNum("sell_price", 250), Item_Finite);
				Shop_SetCallbacks(_, OnUseItem);
				Shop_EndItem();
			}
		}
		while (Kv.GotoNextKey());
	}
}

public ShopAction OnUseItem(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] cItem, bool isOn, bool elapsed)
{
	if (!IsClientInGame(iClient))
	{
		return Shop_Raw;
	}
	
	Shop_ToggleClientCategoryOff(iClient, category_id);
	
	Kv.Rewind();
	
	char cSoundPath[PLATFORM_MAX_PATH], cName[32];
	
	bool bAlive, 
		bRanged;
		
	float fVolume, fTime;
	if (Kv.JumpToKey(cItem, false))
	{
		Kv.GetString("name", cName, sizeof(cName));
		Kv.GetString("sound_path", cSoundPath, PLATFORM_MAX_PATH);
		bAlive = view_as<bool>(Kv.GetNum("alive", 1));
		bRanged = view_as<bool>(Kv.GetNum("range", 0));
		fVolume = Kv.GetFloat("volume", 1.0);
		fTime = Kv.GetFloat("time", 0.0);
		
		if (bAlive || bRanged)
		{
			if (!IsPlayerAlive(iClient))
			{
				PrintToChat(iClient, "%t", "Must_Be_Alive");
				return Shop_Raw;
			}
		}
		
		if (g_iRoundUses != 0 && g_iRoundUsesCount[iClient] >= g_iRoundUses)
		{
			PrintToChat(iClient, "%t", "Round_Limit");
			return Shop_Raw;
		}
		
		if (g_iMapUses != 0 && g_iMapUsesCount[iClient] >= g_iMapUses)
		{
			PrintToChat(iClient, "%t", "Map_Limit");
			return Shop_Raw;
		}
		
		if(g_hCommonCooldownTimer || g_hSoundTimer)
		{
			PrintToChat(iClient, "%t", "Common_Timer_Limit");
			return Shop_Raw;
		}
		
		if(g_hCooldownTimer[iClient])
		{
			PrintToChat(iClient, "%t", "Private_Timer_Limit");
			return Shop_Raw;
		}
		
		if(g_eGameEngine == Engine_CSGO) Format(cSoundPath, PLATFORM_MAX_PATH, "*%s", cSoundPath);
		
		if(StartSound(iClient, cSoundPath, bRanged, fVolume))
		{
			if(g_iCooldown > 0)
			{
				g_hCooldownTimer[iClient] = CreateTimer(float(g_iCooldown), PrivateCooldownTimer, iClient);
			}
			
			if(g_iCommonCooldown > 0)
			{
				g_hCommonCooldownTimer = CreateTimer(float(g_iCommonCooldown), CooldownTimer);
			}
			
			if(1 == FloatCompare(fTime, 0.0))
			{
				g_hSoundTimer = CreateTimer(fTime, Sound_Lenght_Timer);
			}
			
			g_iRoundUsesCount[iClient]++;
			g_iMapUsesCount[iClient]++;
			PrintToChat(iClient, "%t", "Used");
			PrintToChatAllEdit(iClient, cName);
			
			return Shop_UseOn;
		}
		else return Shop_Raw;
	}

	PrintToChat(iClient, "%t", "Error", cItem);
	
	return Shop_Raw;
}

public Action PrivateCooldownTimer(Handle hTimer, any iClient)
{
	if(!g_hSoundTimer && !g_hCommonCooldownTimer) PrintToChat(iClient, "%t", "Ready");
	g_hCooldownTimer[iClient] = null;
	return Plugin_Stop;
}

public Action CooldownTimer(Handle hTimer)
{
	g_hCommonCooldownTimer = null;
	return Plugin_Stop;
}

public Action Sound_Lenght_Timer(Handle hTimer)
{
	g_hSoundTimer = null;
	return Plugin_Stop;
}

bool StartSound(int iClient, const char[] cSoundPath, bool bRanged, float fVolume)
{
	if (bRanged)
	{
		float fPos[3];
		GetClientAbsOrigin(iClient, fPos);
		
		EmitAmbientSound(cSoundPath, fPos, iClient, _, _, fVolume);
		
		return true;
	}
	else if(!bRanged)
	{
		EmitSoundToAll(cSoundPath, _, _, _, _, fVolume);
		return true;
	}
	else return false;
}

void PrintToChatAllEdit(int iClient, const char[] cName)
{
	char name[64];
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && i != iClient)
	{
		GetClientName(iClient, name, sizeof(name));
		PrintToChat(i, "%t", "Announce", name, cName);
	}
}