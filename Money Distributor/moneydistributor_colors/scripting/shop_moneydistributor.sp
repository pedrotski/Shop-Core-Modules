#pragma semicolon 1

#include <sourcemod>
#include <shop>

#include <colors>

#define PLUGIN_VERSION	"1.4.3"

new Handle:g_hInterval;
new Handle:g_hMoneyPerTick;
new Handle:h_timer[MAXPLAYERS+1];

new bool:bRoundEnd, bool:bStopRoundEnd;

new Handle:kv;

public Plugin:myinfo =
{
    name        = "[Shop] Money Distributor",
    author      = "FrozDark (HLModders LLC)",
    description = "Money Distributor component for [Shop]",
    version     = PLUGIN_VERSION,
    url         = "www.hlmod.ru"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("GetUserMessageType");
}

public OnPluginStart() 
{
	CreateConVar("sm_shop_credits_version", PLUGIN_VERSION, "Money distributor version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
	
	g_hInterval = CreateConVar("sm_shop_credits_interval", "60.0", "The interval of timer. Less than 1 to disable", 0, true, 0.0, false);
	g_hMoneyPerTick = CreateConVar("sm_shop_credits_amount", "5", "Amount of credits all players get every time.", 0, true, 1.0);
	
	HookConVarChange(CreateConVar("sm_shop_credits_stop_events_on_round_end", "1", "Don't listen to events on round end", 0, true, 0.0, true, 1.0), OnEventListenChange);
	
	HookConVarChange(g_hInterval, OnIntervalChange);
	
	AutoExecConfig(true, "shop_moneydistributor", "shop");
	
	HookEvent("player_team", OnPlayerTeam);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !(1 < GetClientTeam(i) < 4)) continue;
		OnClientDisconnect_Post(i);
		h_timer[i] = CreateTimer(60.0, GivePoints, i, TIMER_REPEAT);
	}
	
	RegAdminCmd("shop_money_reload", Command_Reload, ADMFLAG_ROOT);
	Command_Reload(0,0);
	
	if (HookEventEx("round_end", OnRoundStartEnd))
	{
		HookEvent("round_start", OnRoundStartEnd);
	}
	
	LoadTranslations("shop_moneydistributor.phrases");
}

public OnIntervalChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !(1 < GetClientTeam(i) < 4)) continue;
		
		Create(i);
	}
}

public OnClientDisconnect_Post(client)
{
	if (h_timer[client] != INVALID_HANDLE)
	{
		KillTimer(h_timer[client]);
		h_timer[client] = INVALID_HANDLE;
	}
}

Create(client)
{
	OnClientDisconnect_Post(client);
	
	new Float:interval = GetConVarFloat(g_hInterval);
	if (interval < 1.0)
	{
		return;
	}
	
	h_timer[client] = CreateTimer(interval, GivePoints, client, TIMER_REPEAT);
}

public OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || IsFakeClient(client)) return;
	
	switch (GetEventInt(event, "team"))
	{
		case 2, 3 :
		{
			Create(client);
		}
		default :
		{
			OnClientDisconnect_Post(client);
		}
	}
}

public Action:GivePoints(Handle:timer, any:client)
{
	new amount = GetConVarInt(g_hMoneyPerTick);
	new gain = Shop_GiveClientCredits(client, amount, CREDITS_BY_NATIVE);
	if (gain != -1)
	{
		CPrintToChat(client, "%t", "credits_gain", gain);
	}
}

public OnEventListenChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	bStopRoundEnd = bool:StringToInt(newValue);
	if (!bStopRoundEnd)
	{
		bRoundEnd = false;
	}
}

public OnRoundStartEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (StrEqual(name, "round_end"))
	{
		if (bStopRoundEnd)
		{
			bRoundEnd = true;
		}
	}
	else
	{
		bRoundEnd = false;
	}
}

public Action:Command_Reload(client, args)
{
	decl String:buffer[PLATFORM_MAX_PATH];
	if (kv != INVALID_HANDLE)
	{
		KvRewind(kv);
		if (KvGotoFirstSubKey(kv))
		{
			do
			{
				if (KvGetNum(kv, "hooked", 0) != 0)
				{
					KvGetSectionName(kv, buffer, sizeof(buffer));
					UnhookEvent(buffer, OnSomeEvent, KvGetNum(kv, "no_copy", 0) == 1 ? EventHookMode_PostNoCopy : EventHookMode_Post);
				}
			} while (KvGotoNextKey(kv));
		}
		CloseHandle(kv);
	}
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "moneydistributor.txt");
	
	kv = CreateKeyValues("Events");
	
	if (!FileToKeyValues(kv, buffer))
	{
		ThrowError("Could not parse %s", buffer);
	}
	
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, buffer, sizeof(buffer));
			if (HookEventEx(buffer, OnSomeEvent, KvGetNum(kv, "no_copy", 0) == 1 ? EventHookMode_PostNoCopy : EventHookMode_Post))
			{
				KvSetNum(kv, "hooked", 1);
			}
			else
			{
				LogError("Invalid event \"%s\"", buffer);
			}
		} while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
}

public OnSomeEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bRoundEnd || !KvJumpToKey(kv, name)) return;
	
	if (KvGotoFirstSubKey(kv))
	{
		decl String:buffer[64];
		decl String:section[32], String:type[12], String:text[256];
		do
		{
			KvGetSectionName(kv, section, sizeof(section));
			if (StrEqual(section, "all", false))
			{
				new credits = KvGetNum(kv, "credits", 0);
				if (credits == 0)
				{
					continue;
				}
				
				new team, teamfilter;
				new bool:alive = bool:KvGetNum(kv, "alive", 0);
				
				KvGetString(kv, "team", buffer, sizeof(buffer), "0");
				if (String_IsNumeric(buffer) && strlen(buffer) == 1)
				{
					team = StringToInt(buffer);
				}
				else
				{
					team = GetEventInt(event, buffer);
				}
				if (team == 0)
				{
					KvGetString(kv, "teamfilter", buffer, sizeof(buffer), "0");
					if (String_IsNumeric(buffer) && strlen(buffer) == 1)
					{
						teamfilter = StringToInt(buffer);
					}
					else
					{
						teamfilter = GetEventInt(event, buffer);
					}
				}
				decl String:sCredits[12];
				KvGetString(kv, "text", text, sizeof(text), "");
				
				decl String:bump[256];
				for (new client = 1; client <= MaxClients; client++)
				{
					if (IsClientInGame(client) && !IsFakeClient(client))
					{
						if (alive && !IsPlayerAlive(client))
						{
							continue;
						}
						new cl_team = GetClientTeam(client);
						if (team != 0 && cl_team != team)
						{
							continue;
						}
						if (teamfilter != 0 && cl_team == teamfilter)
						{
							continue;
						}
						strcopy(bump, sizeof(bump), text);
						
						new gain;
						
						if (credits > 0)
						{
							gain = Shop_GiveClientCredits(client, credits, CREDITS_BY_NATIVE);
						}
						else
						{
							gain = Shop_TakeClientCredits(client, credits*-1, CREDITS_BY_NATIVE);
						}
						
						if (bump[0])
						{
							IntToString(gain, sCredits, sizeof(sCredits));
							ReplaceString(bump, sizeof(bump), "{credits}", sCredits, false);
							TrimString(bump);
						}
						
						if (bump[0])
						{
							CPrintToChat(client, bump);
						}
					}
				}
				
				continue;
			}
			new credits = KvGetNum(kv, "credits", 0);
			if (credits == 0)
			{
				continue;
			}
			KvGetString(kv, "type", type, sizeof(type), "int");
			
			new client;
			if (StrEqual(type, "userid", false))
			{
				client = GetClientOfUserId(GetEventInt(event, section));
				if (!client || !IsClientInGame(client))
				{
					continue;
				}
			}
			else if (StrEqual(type, "int", false))
			{
				client = GetEventInt(event, section);
				if (!(0 < client <= MaxClients) || !IsClientInGame(client))
				{
					continue;
				}
			}
			else
			{
				LogError("Invelid type set \"%s\"", type);
				continue;
			}
			if (IsFakeClient(client))
			{
				continue;
			}
			
			new gain;
			
			if (credits > 0)
			{
				gain = Shop_GiveClientCredits(client, credits, CREDITS_BY_NATIVE);
			}
			else
			{
				gain = Shop_TakeClientCredits(client, credits*-1, CREDITS_BY_NATIVE);
			}
			
			KvGetString(kv, "text", text, sizeof(text), "");
			if (text[0])
			{
				IntToString(gain, type, sizeof(type));
				ReplaceString(text, sizeof(text), "{credits}", type, false);
				CPrintToChat(client, text);
			}
		} while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
}

stock bool:String_IsNumeric(const String:str[])
{	
	new x=0;
	new numbersFound=0;

	while (str[x] != '\0') {

		if (IsCharNumeric(str[x])) {
			numbersFound++;
		}
		else {
			return false;
		}
		
		x++;
	}
	
	if (!numbersFound) {
		return false;
	}
	
	return true;
}