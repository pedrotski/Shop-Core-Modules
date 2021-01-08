// Version 1.0
// Release
// Version 1.1
// Fix logs when changing a map
// Pseudo optimization
// Added cvar "shop_roll_now" // When to start the draw? (1 immediately / 0 after the end of the round)
// Added cvar "shop_roll_interval" // The interval between repetitions of the drawing
// Added cvar "shop_roll_admin" // Who is this plugin for (1 players / 0 admins)
// Version 1.1.1
// Removed unnecessary debug
// Added the winnings amount to the transfer file
// Version 1.1.2
// Fix the error "Translation string formatted incorrectly - missing at least 1 parameters (arg 4)"
// Version 1.2
// Fixed grammatical errors in the translation file
// Fix if the player wrote the command but did not enter the number for the drawing ala "endless drawing"
// Fix error Exception reported: Client index 0 is invalid
// Added cvar "shop_roll_min_players" // Minimum number of players to start the draw
// Improved! Roll command if it is written by the admin (who has access to! Shop -> Admin panel) and starts the drawing, it will write that it was launched by the admin instead of the player, even with shop_roll_admin 1
// Version 1.2.1
// Fix "shop_roll1.phrases.txt" -> "shop_roll.phrases.txt"
// Added a bunch of checks for credits refund
// Version 1.2.2
// Fix error Exception reported: Invalid convar handle 0 (error 4) (Line 117 [GetConVarString])
// Pseudo optimization v2 (thanks to Drumanid) there were still moments, but as they say, it will do, though a little controversial
// Version 1.2.3
// Fix error Exception reported: Client 11 is not in game (Line 523 [PrintToChat]) returned checks

#include <shop>
#include <csgo_colors>

//#define COLOR_CENTER "#00ff00" // Center color
//#define COLOR_ON_THE_SIDES "#ff0000" // Side color
//#define COLOR_FROM_THE_CENTER "#ffff00" // Color from center to sides

int g_iMin,
	g_iMax,
	g_iNum5[5],
	g_iInreval,
	g_iRollPrize,
	g_iMinPlayers,
	g_iPreTimeRoll,
	g_iClientIsRoll,
	g_iConvarTimeToRoll,
	g_iShopFlags;

bool g_bNow,
	 g_bRoll,
	 g_bRollA,
	 g_bAdmin,
	 g_bMsgAnons,
	 g_bUpDownMsg,
	 g_bMapChange,
	 g_bSayCMD[MAXPLAYERS+1];

char COLOR_CENTER[14],
	 COLOR_ON_THE_SIDES[14],
	 COLOR_FROM_THE_CENTER[14];

ArrayList g_hArrayList;

ConVar g_hNow,
	   g_hiMin,
	   g_hiMax,
	   g_hAdmin,
	   g_hInreval,
	   g_hMsgAnons,
	   g_hUpDownMsg,
	   g_hMinPlayers,
	   g_hiConvarTimeToRoll,
	   g_hCOLOR_CENTER,
	   g_hCOLOR_ON_THE_SIDES,
	   g_hCOLOR_FROM_THE_CENTER,
	   g_hShopFlag;

public Plugin myinfo =
{
	name		= "[Shop] Roll",
	author		= "Faya™ (DS: Faya™#8514)",
	version		= "1.2.3",
	url			= "http://hlmod.ru"
};

public void OnPluginStart()
{
	g_hArrayList = new ArrayList(ByteCountToCells(64));

	RegConsoleCmd("sm_roll", CMD_CallBack);

	HookEvent("round_end", eRE);

	if(Shop_IsStarted())
		Shop_Started();

	g_hiConvarTimeToRoll = CreateConVar("shop_roll_time_to_roll", "20", "Time before the start of the draw in seconds", _, true, 1.0, true, 60.0);
	g_hNow = CreateConVar("shop_roll_now", "1", "When to start the draw? (1 immediately / 0 after the end of the round)", _, true, 0.0, true, 1.0);
	g_hiMin = CreateConVar("shop_roll_min_prize", "20", "Minimum amount for the draw", _, true, 1.0, true, 999999.0);
	g_hiMax = CreateConVar("shop_roll_max_prize", "100", "Maximum amount for the draw", _, true, 1.0, true, 9999999.0);
	g_hAdmin = CreateConVar("shop_roll_admin", "1", "Who is this plugin for (1 players / 0 admins) Requires server restart!", _, true, 0.0, true, 1.0);
	g_hInreval = CreateConVar("shop_roll_interval", "60", "Draw repetition interval", _, true, 1.0, true, 3600.0);
	g_hMsgAnons = CreateConVar("shop_roll_msg_anons", "1", "On / off notification about who took part", _, true, 0.0, true, 1.0);
	g_hUpDownMsg = CreateConVar("shop_roll_UpDonwMsg", "1", "Turn on / off spaces at the top and bottom of the notification", _, true, 0.0, true, 1.0);
	g_hMinPlayers = CreateConVar("shop_roll_min_players", "2", "Minimum number of players to start the draw", _, true, 1.0, true, 64.0);
	g_hCOLOR_CENTER = CreateConVar("shop_roll_HINT_COLOR_CENTER", "#00ff00", "Color in the center of the hint");
	g_hCOLOR_ON_THE_SIDES = CreateConVar("shop_roll_HINT_COLOR_ON_THE_SIDES", "#ff0000", "Color on the sides in hint");
	g_hCOLOR_FROM_THE_CENTER = CreateConVar("shop_roll_HINT_COLOR_FROM_THE_CENTER", "#ffff00", "Color from center to sides in hint");

	g_iConvarTimeToRoll = g_hiConvarTimeToRoll.IntValue;
	g_bNow = GetConVarBool(g_hNow);
	g_iMin = g_hiMin.IntValue;
	g_iMax = g_hiMax.IntValue;
	g_bAdmin = GetConVarBool(g_hAdmin);
	g_iInreval = g_hInreval.IntValue;
	g_bMsgAnons = GetConVarBool(g_hMsgAnons);
	g_bUpDownMsg = GetConVarBool(g_hUpDownMsg);
	g_iMinPlayers = g_hMinPlayers .IntValue;
	GetConVarString(g_hCOLOR_CENTER, COLOR_CENTER, sizeof COLOR_CENTER);
	GetConVarString(g_hCOLOR_ON_THE_SIDES, COLOR_ON_THE_SIDES, sizeof COLOR_ON_THE_SIDES);
	GetConVarString(g_hCOLOR_FROM_THE_CENTER, COLOR_FROM_THE_CENTER, sizeof COLOR_FROM_THE_CENTER);

	HookConVarChange(g_hiConvarTimeToRoll, Hook_CallBack);
	HookConVarChange(g_hNow, Hook_CallBack);
	HookConVarChange(g_hiMin, Hook_CallBack);
	HookConVarChange(g_hiMax, Hook_CallBack);
	HookConVarChange(g_hAdmin, Hook_CallBack);
	HookConVarChange(g_hInreval, Hook_CallBack);
	HookConVarChange(g_hMsgAnons, Hook_CallBack);
	HookConVarChange(g_hUpDownMsg, Hook_CallBack);
	HookConVarChange(g_hMinPlayers, Hook_CallBack);
	HookConVarChange(g_hCOLOR_CENTER, Hook_CallBack);
	HookConVarChange(g_hCOLOR_ON_THE_SIDES, Hook_CallBack);
	HookConVarChange(g_hCOLOR_FROM_THE_CENTER, Hook_CallBack);

	g_iPreTimeRoll = GetTime();

	LoadTranslations("shop_roll.phrases.txt");
	AutoExecConfig(true, "shop_roll", "shop");
}

public void Hook_CallBack(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_hiConvarTimeToRoll)
		g_iConvarTimeToRoll = g_hiConvarTimeToRoll.IntValue;
	else if(convar == g_hNow)
		g_bNow = GetConVarBool(g_hNow);
	else if(convar == g_hiMin)
		g_iMin = g_hiMin.IntValue;
	else if(convar == g_hiMax)
		g_iMax = g_hiMax.IntValue;
	else if(convar == g_hAdmin)
		g_bAdmin = GetConVarBool(g_hAdmin);
	else if(convar == g_hInreval)
		g_iInreval = g_hInreval.IntValue;
	else if(convar == g_hMsgAnons)
		g_bMsgAnons = GetConVarBool(g_hMsgAnons);
	else if(convar == g_hUpDownMsg)
		g_bUpDownMsg = GetConVarBool(g_hUpDownMsg);
	else if(convar == g_hMinPlayers)
		g_iMinPlayers = g_hMinPlayers.IntValue;
	else if(convar == g_hCOLOR_CENTER)
		GetConVarString(g_hCOLOR_CENTER, COLOR_CENTER, sizeof COLOR_CENTER);
	else if(convar == g_hCOLOR_ON_THE_SIDES)
		GetConVarString(g_hCOLOR_ON_THE_SIDES, COLOR_ON_THE_SIDES, sizeof COLOR_ON_THE_SIDES);
	else if(convar == g_hCOLOR_FROM_THE_CENTER)
		GetConVarString(g_hCOLOR_FROM_THE_CENTER, COLOR_FROM_THE_CENTER, sizeof COLOR_FROM_THE_CENTER);
	else if(convar == g_hShopFlag)
		g_iShopFlags = ReadFlagString(newValue);
}

public void OnMapStart()
{
	g_bMapChange = false;
	g_bRollA = false;
}

public void OnMapEnd()
{
	g_bMapChange = true;
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
	
	if(g_bAdmin)
		Shop_RemoveFromFunctionsMenu(FunctionDisplay, FunctionSelect);
	else
		Shop_RemoveFromAdminMenu(FunctionDisplay, FunctionSelect);
}

public Shop_Started()
{
	g_hShopFlag = FindConVar("sm_shop_admin_flags");

	char szBuffer[PLATFORM_MAX_PATH];
	GetConVarString(g_hShopFlag, szBuffer, sizeof szBuffer);
	g_iShopFlags = ReadFlagString(szBuffer);

	HookConVarChange(g_hShopFlag, Hook_CallBack);
	
	if(g_bAdmin)
		Shop_AddToFunctionsMenu(FunctionDisplay, FunctionSelect);
	else
		Shop_AddToAdminMenu(FunctionDisplay, FunctionSelect);
}

public int FunctionDisplay(int iClient, char[] buffer, int maxlength)
{
	char szBuffer[128];
	FormatEx(szBuffer, sizeof szBuffer, "%T", "ROLL_SHOP_DISPLAY", iClient);
	strcopy(buffer, maxlength, szBuffer);
}

public bool FunctionSelect(int iClient)
{
	CMD_CallBack(iClient, 0);
	//return true;
}

public Action CMD_CallBack(int iClient, int args)
{
	if(iClient && !IsFakeClient(iClient))
	{
		if(g_bAdmin)
		{
			if(!CanIPlay(1))
			{
				CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_NEED_MIN_PLAYERS", g_iMinPlayers);

				return Plugin_Handled;
			}
			if(GetTime() <= (g_iPreTimeRoll + g_iInreval))
			{
				int i = (g_iInreval - (GetTime() - g_iPreTimeRoll));
				if(i > 60)
					CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_INTERVAL_MIN", RoundToFloor(float(i / 60)));
				else
					CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_INTERVAL_SEC", i);					

				return Plugin_Handled;
			}
		}
		else
		{
			if(!(GetUserFlagBits(iClient) & g_iShopFlags))
			{
				CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_NO_ROOT");

				return Plugin_Handled;
			}
		}

		if(!g_bRollA)
		{
			g_bSayCMD[iClient] = true;
			CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_PRE_START_1", g_iMin, g_iMax);
			CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_PRE_START_2");
		}
		else
			CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_ALREADY_COMING");
	}

	return Plugin_Handled;
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] sArgs)
{
	if(g_bSayCMD[iClient])
	{
		if(!g_bRollA)
		{
			int iArgs = StringToInt(sArgs);
			if(!(g_iMin <= iArgs <= g_iMax))
			{
				CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", !NumericInStr(sArgs) ? "PRE_ROLL_YOU_SAY_STRING" : "PRE_ROLL_INVALID_NUMBER");
/*
				if(!NumericInStr(sArgs))
					CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "PRE_ROLL_YOU_SAY_STRING");
				else
					CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "PRE_ROLL_INVALID_NUMBER");
*/
				g_bSayCMD[iClient] = false;

				return Plugin_Handled;
			}
			if(Shop_GetClientCredits(iClient) < iArgs)
			{
				CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "PRE_ROLL_NO_MONEY");
				g_bSayCMD[iClient] = false;

				return Plugin_Handled;
			}

		
			g_bSayCMD[iClient] = false;
			g_bRollA = true;
			g_iClientIsRoll = iClient;
			g_iRollPrize = iArgs;
			Shop_TakeClientCredits(iClient, iArgs);

			if(g_bUpDownMsg)
				CGOPrintToChatAll("%t", "UP_STRING");
			if(g_bAdmin)
			{
				CGOPrintToChatAll("%t %t", "ROLL_PREFIX", GetUserFlagBits(iClient) & g_iShopFlags ? "ROLL_START_1_ADM" : "ROLL_START_1", iClient, g_iRollPrize);
/*
				if(GetUserFlagBits(iClient) & g_iShopFlags)
					CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_START_1_ADM", iClient, g_iRollPrize);
				else
					CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_START_1", iClient, g_iRollPrize);
*/
			}
			else
				CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_START_1_ADM", iClient, g_iRollPrize);
			if(g_bNow)
			{
				g_hArrayList.Clear();
				StartPanel();
			}
			else
			{
				g_bRoll = true;
				CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_START_2");
			}
			if(g_bUpDownMsg)
				CGOPrintToChatAll("%t", "DOWN_STRING");

			return Plugin_Handled;
		}
		else
		{
			CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_ALREADY_COMING");
			g_bSayCMD[iClient] = false;
		}
	}

	return Plugin_Continue;
}

public Action eRE(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bRoll)
	{
		g_bRoll = false;
		g_hArrayList.Clear();
		StartPanel();
	}
}

void StartPanel()
{
	char szBuffer[256];
	Panel hPanel = new Panel();
	FormatEx(szBuffer, sizeof szBuffer, "Draw For Credits \n \nOrganizer: %N \nIn The Draw: %i \n \n ", g_iClientIsRoll, g_iRollPrize);
	hPanel.SetTitle(szBuffer);
	hPanel.DrawItem("Participate");
	hPanel.DrawItem("Do Not Participate");
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
			if(i != g_iClientIsRoll)
				hPanel.Send(i, PanelHandler_MyPanel, g_iConvarTimeToRoll);

	delete hPanel;

	CreateTimer(1.0, Timer_CallBack, g_iConvarTimeToRoll);
}

public Action Timer_CallBack(Handle timer, any fi)
{
	if(g_bMapChange)
	{
		if(g_iClientIsRoll && IsClientInGame(g_iClientIsRoll) && !IsFakeClient(g_iClientIsRoll) && !IsClientSourceTV(g_iClientIsRoll))
		{
			CGOPrintToChat(g_iClientIsRoll, "%t %t", "ROLL_PREFIX", "MONEY_BACK", g_iRollPrize);
			Shop_GiveClientCredits(g_iClientIsRoll, g_iRollPrize, IGNORE_FORWARD_HOOK);
		}
		return Plugin_Stop;
	}
	if(fi-- == 0)
	{
		if(g_bUpDownMsg)
			CGOPrintToChatAll("%t", "UP_STRING");
		if(!CanIPlay(0))
		{
			g_bRollA = false;
			CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_NO_MIN_PLAYERS", g_iMinPlayers);
			if(g_iClientIsRoll && IsClientInGame(g_iClientIsRoll) && !IsFakeClient(g_iClientIsRoll) && !IsClientSourceTV(g_iClientIsRoll))
			{
				Shop_GiveClientCredits(g_iClientIsRoll, g_iRollPrize, IGNORE_FORWARD_HOOK);
				CGOPrintToChat(g_iClientIsRoll, "%t %t", "ROLL_PREFIX", "MONEY_BACK", g_iRollPrize);
			}
			if(g_bUpDownMsg)
				CGOPrintToChatAll("%t", "DOWN_STRING");

			return Plugin_Stop;
		}
		int iLenght = g_hArrayList.Length;
		if(iLenght > 0)
		{
			CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_START_PLAYER", iLenght);
			GoRoll(iLenght);
		}
		else
		{
			g_bRollA = false;
			CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_STOP_NO_PLAYER");
			if(g_iClientIsRoll && IsClientInGame(g_iClientIsRoll) && !IsFakeClient(g_iClientIsRoll) && !IsClientSourceTV(g_iClientIsRoll))
			{
				Shop_GiveClientCredits(g_iClientIsRoll, g_iRollPrize, IGNORE_FORWARD_HOOK);
				CGOPrintToChat(g_iClientIsRoll, "%t %t", "ROLL_PREFIX", "MONEY_BACK", g_iRollPrize);
			}
		}
		if(g_bUpDownMsg)
			CGOPrintToChatAll("%t", "DOWN_STRING");

		return Plugin_Stop;
	}

	PrintHintTextToAll("%t", "ROLL_TIMER", COLOR_CENTER, fi);
	CreateTimer(1.0, Timer_CallBack, fi);

	return Plugin_Continue;
}

public int PanelHandler_MyPanel(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_Timeout)
				CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_TIMEOUT");
			if(iItem == MenuCancel_Interrupted)
				CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "ROLL_INTERRUPTED");
		}
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 1:
				{
					char szAuth[32];
					GetClientAuthId(iClient, AuthId_Steam2, szAuth, sizeof szAuth);
					g_hArrayList.PushString(szAuth);
					if(g_bMsgAnons)
						CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "PLAYER_ACCEPT_ROLL_PRINT_ALL", iClient, g_hArrayList.Length);
					else
						CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "PLAYER_ACCEPT_ROLL_PRINT_CLIENT", g_hArrayList.Length);
					
				}
				case 2:
					CGOPrintToChat(iClient, "%t %t", "ROLL_PREFIX", "PLAYER_CANCEL_ROLL");
			}
		}
	}

	return 0;
}

void GoRoll(int iLenght)
{
	for(int i; i < 5; i++)
		g_iNum5[i] = GetRandomInt(1, iLenght);

	PrintHintTextToAll("%t", "ROLL_PRINT", COLOR_FROM_THE_CENTER, g_iNum5[0], COLOR_ON_THE_SIDES, g_iNum5[1], COLOR_CENTER, g_iNum5[2], COLOR_ON_THE_SIDES, g_iNum5[3], COLOR_FROM_THE_CENTER, g_iNum5[4]);

	CreateTimer(0.2, Roll_Timer_CallBack, iLenght, TIMER_REPEAT);
}

public Action Roll_Timer_CallBack(Handle timer, any iLenght)
{
	if(g_bMapChange)
	{
		if(g_iClientIsRoll && IsClientInGame(g_iClientIsRoll) && !IsFakeClient(g_iClientIsRoll) && !IsClientSourceTV(g_iClientIsRoll))
		{
			CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_END_REASON_MAPCHANGE");
			CGOPrintToChat(g_iClientIsRoll, "%t %t", "ROLL_PREFIX", "MONEY_BACK", g_iRollPrize);
			Shop_GiveClientCredits(g_iClientIsRoll, g_iRollPrize, IGNORE_FORWARD_HOOK);
		}
		return Plugin_Stop;
	}
	static int iN;
	if(++iN == 16 || iN == 21 || iN == 24 || iN == 26 || iN == 28 || iN > 28 && iN < 64 || iN == 64 || iN == 66 || iN == 68 || iN == 71 || iN == 75 || iN == 79)
	{
		for(int i; i < sizeof g_iNum5 - 1; i++)
			g_iNum5[i] = g_iNum5[i + 1];

		PrintHintTextToAll("%t", "ROLL_PRINT", COLOR_ON_THE_SIDES, g_iNum5[0], COLOR_FROM_THE_CENTER, g_iNum5[1], COLOR_CENTER, g_iNum5[2], COLOR_FROM_THE_CENTER, g_iNum5[3], COLOR_ON_THE_SIDES, g_iNum5[4] = GetRandomInt(1, iLenght));
		for(int i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				ClientCommand(i, "playgamesound *ui/csgo_ui_crate_item_scroll.wav");
	}
	else if(iN == 89)
	{
		iN = 0;
		int iClient; char szAuth[32];
		g_hArrayList.GetString(g_iNum5[2] - 1, szAuth, sizeof szAuth);

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
			{
				char szAuth_Hm[32];
				GetClientAuthId(i, AuthId_Steam2, szAuth_Hm, sizeof szAuth_Hm);
				if(strcmp(szAuth_Hm, szAuth) == 0)
				{
					iClient = i;
					ClientCommand(i, "playgamesound *ui/item_drop6_ancient.wav");
				}
				else if(i != g_iClientIsRoll)
					ClientCommand(i, "playgamesound *music/skog_01/lostround.mp3");
			}
		}

		if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient) && !IsClientSourceTV(iClient))
		{
			CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_WIN_TICKET", g_iNum5[2], iClient, g_iRollPrize);
			Shop_GiveClientCredits(iClient, g_iRollPrize, IGNORE_FORWARD_HOOK);
		}
		else
		{
			if(g_iClientIsRoll && IsClientInGame(g_iClientIsRoll) && !IsFakeClient(g_iClientIsRoll) && !IsClientSourceTV(g_iClientIsRoll))
			{
				CGOPrintToChatAll("%t %t", "ROLL_PREFIX", "ROLL_DONT_WIN_PLAYER", g_iNum5[2]);
				CGOPrintToChat(g_iClientIsRoll, "%t %t", "ROLL_PREFIX", "MONEY_BACK", g_iRollPrize);
				Shop_GiveClientCredits(g_iClientIsRoll, g_iRollPrize, IGNORE_FORWARD_HOOK);
			}
		}

		g_iPreTimeRoll = GetTime();
		g_bRollA = false;
		g_iClientIsRoll = 0;

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

stock bool NumericInStr(const char[] buffer)
{
	for(int i, len = strlen(buffer); i < len; ++i)
	{
		if(IsCharNumeric(buffer[i]))
			return true;
	}
	return false;
}

bool CanIPlay(int iSwitch)
{
	if(iSwitch)
	{
		int iPlayers = 0;
		for(int i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
				iPlayers++;
		return iPlayers >= g_iMinPlayers ? true:false;
	}
	else
		return g_hArrayList.Length >= g_iMinPlayers ? true:false;
}