#include <sourcemod>
#include <shop>
#include <tas>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[Shop] Bank",
	author = "Tonki_Ton",
	version = "1.0.0",
	url = "vk.com/tonki_ton"
};

int g_iCash[2],
	g_iDays[2],
	g_iInvestCash_Cash[2],
	g_iWarnings,
	g_iBanDays,
	g_iMaxAmountInBank,
	g_iCreditPercent,
	g_iInvestCashPer,
	g_iInvestCashPercent,
	g_iClientID[MAXPLAYERS+1],
	g_iWarningsAmount[MAXPLAYERS+1],
	g_iInvestCash[MAXPLAYERS+1],
	g_iPayable[MAXPLAYERS+1],
	g_iTimeStamp2[MAXPLAYERS+1],
	g_iTimeStamp[MAXPLAYERS+1],
	g_iTemporaryMoney[MAXPLAYERS+1],
	g_iTemporaryDays[MAXPLAYERS+1];

bool g_bRestrict,
	 g_bSwitch[MAXPLAYERS+1],
	 g_bIsPrinting[5][MAXPLAYERS+1];

char g_sClientAuth[MAXPLAYERS+1][36],
	 g_sPluginPrefix[64];

KeyValues g_hKV;

Database g_hDB;

public void OnPluginStart()
{
	if (SQL_CheckConfig("shop_bank"))
	{
		Database.Connect(DataBaseConnect, "shop_bank", 0);
	}
	else	
	{
		KeyValues hKbDb = new KeyValues(NULL_STRING);

		hKbDb.SetString("driver", "sqlite");
		hKbDb.SetString("database", "shop_bank");

		char sError[256];
		g_hDB = SQL_ConnectCustom(hKbDb, sError, sizeof sError, false);

		delete hKbDb;
	
		DataBaseConnect(g_hDB, sError, 1);
	}

	HookEvent("player_spawn", ePS);

	RegConsoleCmd("sm_bank", BankMenu);

	if (Shop_IsStarted())
	{
		Shop_Started();
	}
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && !IsClientSourceTV(i))
		{
			OnClientDisconnect(i);
		}
	}
}

public void Shop_Started()
{
	Shop_AddToFunctionsMenu(FunctionDisplay, FunctionSelect);
}

public int FunctionDisplay(int iClient, char[] sBuff, int iMaxlength)
{
	strcopy(sBuff, iMaxlength, "Банк");
}

public bool FunctionSelect(int iClient)
{
	BankMenu(iClient, 0);
	return true;   
}

public void OnMapStart()
{
	if (g_hKV)
	{
		delete g_hKV;
	}

	char sBuff[192];

	g_hKV = new KeyValues("shop_bank");

	BuildPath(Path_SM, sBuff, sizeof sBuff, "configs/shop/bank.ini");

	g_hKV.ImportFromFile(sBuff);

	g_iMaxAmountInBank	  = g_hKV.GetNum("max_amount_in_bank", 10000000);
	g_iInvestCashPer      = g_hKV.GetNum("invest_per", 86400);
	g_iBanDays        	  = g_hKV.GetNum("ban_days", 7);
	g_iWarnings       	  = g_hKV.GetNum("warning_amount", 2);
	g_iInvestCash_Cash[0] = g_hKV.GetNum("min_invest_amount", 100);
	g_iInvestCash_Cash[1] = g_hKV.GetNum("max_invest_amount", 100000);
	g_iCreditPercent	  = g_hKV.GetNum("credit_percent", 7);
	g_iCash[0]		  	  = g_hKV.GetNum("max_amount", 100000);
	g_iCash[1]		  	  = g_hKV.GetNum("min_amount", 10);
	g_iDays[0]		  	  = g_hKV.GetNum("min_days", 1);
	g_iDays[1]		  	  = g_hKV.GetNum("max_days", 14);
	g_iInvestCashPercent  = g_hKV.GetNum("invest_precent", 3);
	g_bRestrict			  = !!g_hKV.GetNum("restrict_transfer", 1);

	g_hKV.GetString("chat_prefix", g_sPluginPrefix, sizeof g_sPluginPrefix);
}

public void ePS(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_iTimeStamp2[iClient] && GetTime() > g_iTimeStamp2[iClient])
	{
		int iExpectedCash = g_iInvestCash[iClient] / 100 * g_iInvestCashPercent;

		if (iExpectedCash > g_iMaxAmountInBank)
		{
			return;
		}

		g_iInvestCash[iClient] += iExpectedCash;
		g_iTimeStamp2[iClient] = GetTime()+g_iInvestCashPer;
	}
}

public Action BankMenu(int iClient, int iArgs)
{
	char sBuff[96], sTime[32];

	Menu hMenu = new Menu(BankMenuHandler);

	if (g_iTimeStamp[iClient] > GetTime())
	{
		GetStringTime(g_iTimeStamp[iClient]-GetTime(), sTime, sizeof sTime);
	}
	else
	{
		strcopy(sTime, sizeof sTime, "Изымается");
	}

	hMenu.SetTitle(g_iPayable[iClient] ? "Банк\nДо принудительного изьятия: %s\n ":"Банк\n ", sTime);

	FormatEx(sBuff, sizeof sBuff, g_iPayable[iClient] ? "Взять кредит [Задолженность %i кредитов]":"Взять кредит", g_iPayable[iClient]);
	hMenu.AddItem(NULL_STRING, sBuff, g_iPayable[iClient] ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);

	FormatEx(sBuff, sizeof sBuff, !g_iPayable[iClient] ? "Погасить задолженность [%i]":"Погасить задолженность", g_iPayable[iClient]);
	hMenu.AddItem(NULL_STRING, "Погасить задолженность\n ", !g_iPayable[iClient] ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	hMenu.AddItem(NULL_STRING, "Вклады");

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int BankMenuHandler(Menu hMenu, MenuAction maAction, int iClient, int iPick)
{
	switch (maAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if (iPick == MenuCancel_ExitBack) Shop_ShowFunctionsMenu(iClient);
		case MenuAction_Select:
		{
			switch(iPick)
			{
				case 0:
				{
					g_hKV.Rewind(); 

					if (g_hKV.JumpToKey("credits"))
					{
						g_bSwitch[iClient] = false;
						ChoiceCredits(iClient);
					}
					else
					{
						g_bIsPrinting[0][iClient] = true;
						TAS_PrintToChat(iClient, "%s{OLIVE}Введите желаемую сумму в чат, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iCash[1], g_iCash[0]);
					}
				}
				case 1:
				{
					g_bIsPrinting[1][iClient] = true;
					TAS_PrintToChat(iClient, "%s{OLIVE}Введите желаемую сумму в чат.", g_sPluginPrefix);
				}
				case 2:
				{
					InvestMenu(iClient);
				}
			}
		}
	}
}

void InvestMenu(int iClient)
{
	Menu hMenu = new Menu(InvestMenuHandler);

	hMenu.SetTitle("Вклад под проценты [Ставка %i%%]\nТекущая сумма вклада: %i\n ", g_iInvestCashPercent, g_iInvestCash[iClient]);

	if (g_iInvestCash_Cash[0] > Shop_GetClientCredits(iClient))
	{
		char sBuff[64];
	
		FormatEx(sBuff, sizeof sBuff, "Сделать вклад [Мин %i]", g_iInvestCash_Cash[0]);
		hMenu.AddItem(NULL_STRING, sBuff,  ITEMDRAW_DISABLED);
	}
	else
	{
		hMenu.AddItem(NULL_STRING, "Сделать вклад");
	}

	hMenu.AddItem(NULL_STRING, "Снять вклад");

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int InvestMenuHandler(Menu hMenu, MenuAction maAction, int iClient, int iPick)
{
	switch (maAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if (iPick == MenuCancel_ExitBack) BankMenu(iClient, 0);
		case MenuAction_Select:
		{
			if (!iPick)
			{
				g_hKV.Rewind(); g_bSwitch[iClient] = true;

				if (g_hKV.JumpToKey("credits_invest"))
				{
					ChoiceCredits(iClient);
				}
				else
				{
					g_bIsPrinting[3][iClient] = true;
					TAS_PrintToChat(iClient, "%s{OLIVE}Введите желаемую сумму вклада в чат, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iInvestCash_Cash[0], g_iInvestCash_Cash[1]);
				}
			}
			else
			{
				g_bIsPrinting[4][iClient] = true;
				TAS_PrintToChat(iClient, "%s{OLIVE}Введите желаемую сумму в чат, {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iInvestCash[iClient]);
			}
		}
	}
}

void ChoiceCredits(int iClient)
{
	Menu hMenu = new Menu(CreditsMenuHandler);

	hMenu.SetTitle("Выберите желаемую сумму\n ");

	if (g_hKV.GotoFirstSubKey(false))
	{
		char sAmount[16], sAmountDisplay[64];
		do
		{
			g_hKV.GetSectionName(sAmount, sizeof sAmount);
			g_hKV.GetString(NULL_STRING, sAmountDisplay, sizeof sAmountDisplay);
			
			hMenu.AddItem(sAmount, sAmountDisplay, g_bSwitch[iClient] && StringToInt(sAmount) > Shop_GetClientCredits(iClient) || g_bSwitch[iClient] && g_iInvestCash[iClient]+StringToInt(sAmount) > g_iInvestCash_Cash[1] ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
		} 
		while (g_hKV.GotoNextKey(false));
	}

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CreditsMenuHandler(Menu hMenu, MenuAction maAction, int iClient, int iPick)
{
	switch (maAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if (iPick == MenuCancel_ExitBack) BankMenu(iClient, 0);
		case MenuAction_Select:
		{
			char sPick[16];
			hMenu.GetItem(iPick, sPick, sizeof sPick);

			if (g_bSwitch[iClient])
			{
				int iAmount;

				g_iInvestCash[iClient] += (iAmount = StringToInt(sPick));
				g_iTimeStamp2[iClient] = GetTime()+g_iInvestCashPer;

				TAS_PrintToChat(iClient, "%s{OLIVE}Вы совершили вклад в банк в размере {RED}%i.", g_sPluginPrefix, iAmount);
				Shop_TakeClientCredits(iClient, iAmount);
				InvestMenu(iClient);
			}
			else
			{
				g_iTemporaryMoney[iClient] = StringToInt(sPick);

				g_hKV.Rewind();

				if (g_hKV.JumpToKey("times"))
				{
					ChoiceTime(iClient);
				}
				else
				{
					g_bIsPrinting[2][iClient] = true;
					TAS_PrintToChat(iClient, "%s{OLIVE}Введите количество дней в чат, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iDays[0], g_iDays[1]);
				}
			}	
		}
	}
}

void ChoiceTime(int iClient)
{
	Menu hMenu = new Menu(TimeMenuHandler);

	hMenu.SetTitle("Выберите срок\n ");

	if (g_hKV.GotoFirstSubKey(false))
	{
		char sTime[32], sAmountTime[64];
		do
		{
			g_hKV.GetSectionName(sTime, sizeof sTime);
			g_hKV.GetString(NULL_STRING, sAmountTime, sizeof sAmountTime);

			hMenu.AddItem(sTime, sAmountTime);
		} 
		while (g_hKV.GotoNextKey(false));
	}

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int TimeMenuHandler(Menu hMenu, MenuAction maAction, int iClient, int iPick)
{
	switch (maAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if (iPick == MenuCancel_ExitBack) BankMenu(iClient, 0);
		case MenuAction_Select:
		{
			char sPick[32];
			hMenu.GetItem(iPick, sPick, sizeof sPick);

			g_iTemporaryDays[iClient] = StringToInt(sPick);
			ConfirmationMenu(iClient);
		}
	}
}

void ConfirmationMenu(int iClient)
{
	char sBuff[96];

	Panel hInfo = new Panel();

	FormatEx(sBuff, sizeof sBuff, "Подтвердите данны\n ", g_iTemporaryMoney[iClient]);
	hInfo.SetTitle(sBuff);

	hInfo.DrawText("Внимание! Вы собираетесь взять кредит.");
	hInfo.DrawText("Имейте ввиду, что на возврат полной суммы");

	FormatEx(sBuff, sizeof sBuff, "у вас будет %i дней. Если по истечению", g_iTemporaryDays[iClient]);
	hInfo.DrawText(sBuff);
	hInfo.DrawText("срока вы не вернете всю сумму, то кредиты");
	hInfo.DrawText("будут изыматься у вас принудительно.");

	hInfo.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	SetPanelCurrentKey(hInfo, 1);
	hInfo.DrawItem("Поставить подпись");
	SetPanelCurrentKey(hInfo, 2);
	hInfo.DrawItem("Порвать контракт");

	hInfo.Send(iClient, ConfirHandler, 0);
}

public int ConfirHandler(Menu hMenu, MenuAction maAction, int iClient, int iPick)
{
	switch (maAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select:
		{
			if (iPick == 1)
			{
				char sTime[32];

				Shop_GiveClientCredits(iClient, g_iTemporaryMoney[iClient], IGNORE_FORWARD_HOOK);
				TAS_PrintToChat(iClient, "%s{OLIVE}Вы взяли кредит на сумму {BLUE}%i {OLIVE}кредитов.", g_sPluginPrefix, g_iTemporaryMoney[iClient]);

				g_iPayable[iClient] = g_iTemporaryMoney[iClient] += ((g_iTemporaryMoney[iClient] / 100) * g_iCreditPercent);
				g_iTimeStamp[iClient] = GetTime()+86400*g_iTemporaryDays[iClient];

				GetStringTime(g_iTemporaryDays[iClient]*86400, sTime, sizeof sTime);
				TAS_PrintToChat(iClient, "%s{OLIVE}Вам необходимо вернуть {BLUE}%i {OLIVE} кредитов, краний срок через {BLUE}%s", g_sPluginPrefix, g_iPayable[iClient], sTime);
				ClientCommand(iClient, "play buttons/button14.wav");
			}
			else
			{
				ClientCommand(iClient, "play buttons/combine_button7.wav");
				BankMenu(iClient, 0);
			}
		}
	}
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] sArgs)
{
	if (g_bIsPrinting[0][iClient])    
	{
		int iBet;

		if ((iBet = StringToInt(sArgs)) <= g_iCash[1] || iBet > g_iCash[0])  
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Некорректная сумма, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iCash[1], g_iCash[0]);
			TAS_PrintToChat(iClient, "%s{OLIVE}Повторите попытку.", g_sPluginPrefix);
			return Plugin_Handled;
		}

		g_iTemporaryMoney[iClient] = iBet;

		g_hKV.Rewind();

		if (g_hKV.JumpToKey("times"))
		{
			ChoiceTime(iClient);
		}
		else
		{
			g_bIsPrinting[2][iClient] = true;
			TAS_PrintToChat(iClient, "%s{OLIVE}Введите количество дней в чат, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iDays[0], g_iDays[1]);
		}

		g_bIsPrinting[0][iClient] = false;
	
		return Plugin_Handled;
	}
	else if (g_bIsPrinting[1][iClient])    
	{
		int iBet;

		if ((iBet = StringToInt(sArgs)) <= 0 || iBet > g_iPayable[iClient] || iBet > Shop_GetClientCredits(iClient))  
		{
			g_bIsPrinting[1][iClient] = false;
			BankMenu(iClient, 0);
			TAS_PrintToChat(iClient, "%s{OLIVE}Некорректная сумма. Сумма не должна привышать сумму вашего долга.", g_sPluginPrefix);
			return Plugin_Handled;
		}

		g_iPayable[iClient] -= iBet;
		Shop_TakeClientCredits(iClient, iBet);

		if (!g_iPayable[iClient])
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Вы погасили всю сумму долга", g_sPluginPrefix);
			g_iTimeStamp[iClient] = 0;
		}
		else
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Вы внесли сумму в размере {BLUE}%i {OLIVE}, до погашения задолженности осталось {BLUE}%i", g_sPluginPrefix, iBet, g_iPayable[iClient]);
		}

		BankMenu(iClient, 0);

		g_bIsPrinting[1][iClient] = false;

		return Plugin_Handled;
	}
	else if (g_bIsPrinting[2][iClient])    
	{
		int iDays;

		if ((iDays = StringToInt(sArgs)) < g_iDays[0] || iDays > g_iDays[1])  
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Неккоректное количество дней, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iDays[0], g_iDays[1]);
			TAS_PrintToChat(iClient, "%s{OLIVE}Повторите попытку.", g_sPluginPrefix);
			return Plugin_Handled;
		}

		g_iTemporaryDays[iClient] = iDays;

		ConfirmationMenu(iClient);

		g_bIsPrinting[2][iClient] = false;

		return Plugin_Handled;
	}
	else if (g_bIsPrinting[3][iClient])    
	{
		int iBet;

		if ((iBet = StringToInt(sArgs)) < g_iInvestCash_Cash[0] || iBet > Shop_GetClientCredits(iClient) || iBet > g_iInvestCash_Cash[1])  
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Некорректная сумма, {RED}%i {OLIVE}мин. {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iInvestCash_Cash[0], g_iInvestCash_Cash[1]);
			TAS_PrintToChat(iClient, "%s{OLIVE}Повторите попытку.", g_sPluginPrefix);
			return Plugin_Handled;
		}

		if (g_iInvestCash[iClient]+iBet > g_iMaxAmountInBank)
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Нелья вложить больше {RED}%i.", g_sPluginPrefix, g_iMaxAmountInBank);
			g_bIsPrinting[3][iClient] = false;
			InvestMenu(iClient);
			return Plugin_Handled;
		}

		g_iInvestCash[iClient] += iBet;
		g_iTimeStamp2[iClient] = GetTime()+g_iInvestCashPer;

		g_bIsPrinting[3][iClient] = false;

		TAS_PrintToChat(iClient, "%s{OLIVE}Вы совершили вклад в банк в размере {RED}%i.", g_sPluginPrefix, iBet);
		Shop_TakeClientCredits(iClient, iBet);
		InvestMenu(iClient);

		return Plugin_Handled;
	}
	else if (g_bIsPrinting[4][iClient])    
	{
		int iBet;

		if ((iBet = StringToInt(sArgs)) < 1 || iBet > g_iInvestCash[iClient])  
		{
			TAS_PrintToChat(iClient, "%s{OLIVE}Некорректная сумма, {RED}%i {OLIVE}макс.", g_sPluginPrefix, g_iInvestCash[iClient]);
			TAS_PrintToChat(iClient, "%s{OLIVE}Повторите попытку.", g_sPluginPrefix);
			return Plugin_Handled;
		}

		g_iInvestCash[iClient] -= iBet;

		g_bIsPrinting[4][iClient] = false;

		TAS_PrintToChat(iClient, "%s{OLIVE}Вы забрали из банка вклад в размере {RED}%i.", g_sPluginPrefix, iBet);
		Shop_GiveClientCredits(iClient, iBet, IGNORE_FORWARD_HOOK);
		InvestMenu(iClient);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnClientAuthorized(int iClient, const char[] sAuth)
{
	if (!IsFakeClient(iClient) && g_hDB)
	{
		char sQuery[256];
		strcopy(g_sClientAuth[iClient], sizeof g_sClientAuth[], sAuth);
		FormatEx(sQuery, sizeof sQuery, "SELECT `id`, `payable`, `payable_timestamp`, `invest`, `invest_timestamp` FROM `bank_main` WHERE `auth` = '%s';", g_sClientAuth[iClient]);
		g_hDB.Query(SQL_Callback_SelectClient, sQuery, GetClientUserId(iClient));
	}

	for (int i; i < 5; i++)
	{
		g_bIsPrinting[i][iClient] = false;
	}
}

public void OnClientDisconnect(int iClient)
{
	if (!IsFakeClient(iClient))
	{
		char sQuery[256];

		FormatEx(sQuery, sizeof sQuery, "UPDATE `bank_main` SET `payable` = %i, `payable_timestamp` = %i, `invest` = %i, `invest_timestamp` = %i WHERE `id` = %i;", g_iPayable[iClient], g_iTimeStamp[iClient], g_iInvestCash[iClient], g_iTimeStamp2[iClient], g_iClientID[iClient]);
		g_hDB.Query(SQL_Callback_ErrorCheck, sQuery);
	}
}

public Action LubeItUp(Handle hTimer, int iClient)
{
	if ((iClient = GetClientOfUserId(iClient)))
	{
		CheckDebt(iClient, Shop_GetClientCredits(iClient));
	}
}

public Action Shop_OnCreditsTransfer(int iClient, int iTarget, int &iAmount_give, int &iAmount_remove, int &iAmount_commission, bool bPercent)
{
	if (g_iPayable[iClient] && g_iTimeStamp[iClient] && GetTime() > g_iTimeStamp[iClient])
	{
		CreateTimer(1.0, LubeItUp, GetClientUserId(iClient));
	}

	if (g_bRestrict && g_iPayable[iClient])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void Shop_OnCreditsTransfered(int iClient, int iTarget, int iAmount_give, int iAmount_remove, int iAmount_commission)
{
	if (g_iPayable[iTarget] && g_iTimeStamp[iTarget] && GetTime() > g_iTimeStamp[iTarget])
	{
		CreateTimer(1.0, LubeItUp, GetClientUserId(iClient));
	}
}

public Action Shop_OnCreditsGiven(int iClient, int &iCredits, int by_who)
{
	if (g_iPayable[iClient] && g_iTimeStamp[iClient] && GetTime() > g_iTimeStamp[iClient])
	{
		CreateTimer(1.0, LubeItUp, GetClientUserId(iClient));
	}
}

public void SQL_Callback_SelectClient(Database hDatabase, DBResultSet hResults, const char[] sError, int iClient)
{
	iClient = GetClientOfUserId(iClient);

	if (!hResults || sError[0])
	{ 
		LogError("SQL_Callback_SelectClient_Error: %s", sError);	
		return;
	}

	if (!iClient || !IsClientAuthorized(iClient))
	{
		return;
	}

	char sName[MAX_NAME_LENGTH*2+1], sQuery[256];
	GetClientName(iClient, sName, sizeof sName);

	for (int i = 0, len = strlen(sName), CharBytes; i < len;)
	{
		if ((CharBytes = GetCharBytes(sName[i])) == 4)
		{
			len -= 4;
			for (int u = i; u <= len; u++)
			{
				sName[u] = sName[u+4];
			}
		}	
		else
		{
			i += CharBytes;
		}
	}

	g_hDB.Escape(sName, sName, sizeof sName);

	if (hResults.FetchRow())
	{
		g_iClientID[iClient] 		 = hResults.FetchInt(0);
		g_iPayable[iClient] 		 = hResults.FetchInt(1);
		g_iTimeStamp[iClient] 		 = hResults.FetchInt(2);
		g_iInvestCash[iClient] 		 = hResults.FetchInt(3);
		g_iTimeStamp2[iClient]		 = hResults.FetchInt(4);

		if (g_iPayable[iClient] && g_iTimeStamp[iClient])
		{
			CreateTimer(10.0, SetShit, GetClientUserId(iClient));
		}

		FormatEx(sQuery, sizeof sQuery, "UPDATE `bank_main` SET `name` = '%s' WHERE `auth` = '%s';", sName, g_sClientAuth[iClient]);
		SQL_FastQuery(g_hDB, sQuery);
	}
	else
	{
		g_iPayable[iClient] 		 = 0;
		g_iTimeStamp[iClient] 		 = 0;
		g_iInvestCash[iClient] 		 = 0;
		g_iTimeStamp2[iClient]		 = 0;

		FormatEx(sQuery, sizeof sQuery, "INSERT INTO `bank_main` (`auth`, `name`) VALUES ( '%s', '%s');", g_sClientAuth[iClient], sName);
		g_hDB.Query(SQL_Callback_CreateClient, sQuery, GetClientUserId(iClient));
	}
}

public Action SetShit(Handle hTimer, int iClient)
{
	if ((iClient = GetClientOfUserId(iClient)))
	{
		char sBuff[192];

		Panel hInfo = new Panel();

		if (GetTime() > g_iTimeStamp[iClient])
		{
			FormatEx(sBuff, sizeof sBuff, "Внимание, у вас имеется непогашенная\nзадоженность в размере %i кредитов\n ", g_iPayable[iClient]);
			hInfo.SetTitle(sBuff);

			hInfo.DrawText("Вы просрочили время выплаты долга");
			hInfo.DrawText("сумма долга будет изыматься принудительно.");

			CheckDebt(iClient, Shop_GetClientCredits(iClient));
		}
		else
		{
			FormatEx(sBuff, sizeof sBuff, "Внимание, у вас имеется непогашенная\nзадоженность в размере %i кредитов\n ", g_iPayable[iClient]);
			hInfo.SetTitle(sBuff);

			char sTime[32];

			GetStringTime(g_iTimeStamp[iClient]-GetTime(), sTime, sizeof sTime);
			FormatEx(sBuff, sizeof sBuff, "Крайний срок погашенния задолжености через %s", sTime);
			hInfo.DrawText(sBuff);
			hInfo.DrawText("Иначе сумма долга начнет изыматься принудительно.");
		}

		hInfo.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
		SetPanelCurrentKey(hInfo, 1);
		hInfo.DrawItem("Понял");

		hInfo.Send(iClient, view_as<MenuHandler>(Placebo), 0);
	}
}

public void SQL_Callback_CreateClient(Database hDatabase, DBResultSet results, const char[] szError, int iClient)
{
	if (szError[0])
	{
		LogError("SQL_Callback_CreateClient: %s", szError);
		return;
	}

	if ((iClient = GetClientOfUserId(iClient)))
	{
		g_iClientID[iClient] = results.InsertId;
	}
}

void Placebo(){}

public void DataBaseConnect(Database hDB, const char[] sError, any data)
{
	if (hDB == null || sError[0])
	{
		SetFailState("Database connect failure: %s", sError);
		return;
	}

	char sDriver[16];
	DBDriver dbdriver = hDB.Driver;
	dbdriver.GetIdentifier(sDriver, sizeof(sDriver));

	g_hDB = hDB;

	switch (sDriver[0])
	{
		case 's':
		{
			g_hDB.Query(SQL_Callback_ErrorCheck, "CREATE TABLE IF NOT EXISTS `bank_main` (\ 
												 `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
												 `auth` VARCHAR(34) NOT NULL,\ 
												 `name` VARCHAR(64) NOT NULL default 'unknown',\ 
												 `payable` INTEGER NOT NULL default '0',\ 
												 `payable_timestamp` INTEGER NOT NULL default '0',\ 
												 `warnings` INTEGER NOT NULL default '0',\ 
												 `invest` INTEGER NOT NULL default '0',\ 
												 `invest_timestamp` INTEGER NOT NULL default '0');");
		}
		case 'm':
		{
			g_hDB.Query(SQL_Callback_ErrorCheck, "CREATE TABLE IF NOT EXISTS `bank_main` (\ 
												 `id` int NOT NULL AUTO_INCREMENT,\ 
												 `auth` varchar(34) NOT NULL,\ 
												 `name` varchar(64) NOT NULL default 'unknown',\ 
												 `payable` int NOT NULL default 0,\  
												 `payable_timestamp` int NOT NULL default 0,\ 
												 `warnings` int NOT NULL default 0,\ 
												 `invest` int NOT NULL default 0\ 
												 `invest_timestamp` int NOT NULL default 0, PRIMARY KEY (`id`)) DEFAULT CHARSET=utf8;");
		}
		default:
		{
			SetFailState("Unknown database type!");
		}
	}

	g_hDB.SetCharset("utf8");

	if (g_hDB)
	{
		char sAuth[36];

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{		
				GetClientAuthId(i, AuthId_Steam2, sAuth, sizeof sAuth);
				OnClientAuthorized(i, sAuth);
			}
		}
	}
}

public void SQL_Callback_ErrorCheck(Database hOwner, DBResultSet hResults, const char[] sError, any data)
{
	if (hResults == null || sError[0])
	{
		LogError("SQL_Callback_ErrorCheck: %s", sError);
	}
}

bool CheckDebt(int iClient, int iCredits)
{
	if (iCredits)
	{
		if (iCredits > g_iPayable[iClient])
		{
			iCredits -= g_iPayable[iClient];
			g_iTimeStamp[iClient] = 0;
			g_iPayable[iClient] = 0;

			Shop_SetClientCredits(iClient, iCredits);
			TAS_PrintToChat(iClient, "%s{OLIVE}У вас были изъяты кредиты и сумма задолженности была погашена.", g_sPluginPrefix);
		}
		else
		{
			g_iPayable[iClient] -= iCredits;
			Shop_SetClientCredits(iClient, 0);
			TAS_PrintToChat(iClient, "%s{OLIVE}У вас были изъяты имеющиеся кредиты, осталось погасить {BLUE}%i кредиты.", g_sPluginPrefix, g_iPayable[iClient]);
		}

		return true;
	}

	return false;
}

void GetStringTime(int time, char[] buffer, int maxlength)
{
    static int dims[] = {60, 60, 24, 30, 12, cellmax};
    static char sign[][] = {"с", "м", "ч", "д", "м", "г"};
    static char form[][] = {"%02i%s%s", "%02i%s %s", "%i%s %s"};
    buffer[0] = EOS;
    int i = 0, f = -1;
    bool cond = false;
    while (!cond) {
        if (f++ == 1)
            cond = true;
        do {
            Format(buffer, maxlength, form[f], time % dims[i], sign[i], buffer);
            if (time /= dims[i++], time == 0)
                return;
        } while (cond);
    }
}