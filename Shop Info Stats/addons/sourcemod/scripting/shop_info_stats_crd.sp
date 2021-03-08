#include <shop>
#include <clientprefs>

int g_iTime,
	g_iMoney[2],
	g_iDynamic[2],
	g_iPlayerMoney[MAXPLAYERS + 1][2];

Handle g_hCookie;

Database g_hDatabase = null;

public Plugin myinfo = 
{
	name = "[Shop] Info Stats (CDR)",
	author = "Faya™ (DS: Faya™#8514)",
	version = "1.1 (PUBLIC)",
	url = "http://hlmod.ru/"
};

public void OnPluginStart()
{
	g_iTime = GetTime();
	ClearTime();

	g_hCookie = RegClientCookie("shop_info_stats", "Shop Info Stats", CookieAccess_Protected);

	if Shop_IsStarted() *then
	{
		Shop_Started();
	}
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
	Shop_RemoveFromFunctionsMenu(FunctionDisplay, FunctionSelect);
}

public void OnClientCookiesCached(int iClient)
{
	if !IsFakeClient(iClient) *then
	{
		g_iPlayerMoney[iClient][0] = 0;
		g_iPlayerMoney[iClient][1] = 0;

		static char szBuffer[18];

		GetClientCookie(iClient, g_hCookie, szBuffer, sizeof szBuffer);

		if szBuffer[0] *then
		{
			static char szExBuffer[3][8];
			ExplodeString(szBuffer, "|", szExBuffer, sizeof szExBuffer, sizeof szExBuffer[]);

			if StringToInt(szExBuffer[2]) == g_iTime *then
			{
				g_iPlayerMoney[iClient][0] = StringToInt(szExBuffer[0]);
				g_iPlayerMoney[iClient][1] = StringToInt(szExBuffer[1]);
			}
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	if !IsFakeClient(iClient) *then
	{
		static char szBuffer[18];

		FormatEx(szBuffer, sizeof szBuffer, "%i|%i|%i", g_iPlayerMoney[iClient][0], g_iPlayerMoney[iClient][1], g_iTime);
		SetClientCookie(iClient, g_hCookie, szBuffer);
	}
}

public void OnMapStart()
{
	if GetTime() > g_iTime *then
	{
		g_iDynamic[0] = g_iDynamic[1] = 0;
		ClearTime();
	}
}

public void Shop_Started()
{
	g_hDatabase = Shop_GetDatabase();

	char szQuery[256], szPrefix[12];

	Shop_GetDatabasePrefix(szPrefix, sizeof szPrefix);
	FormatEx(szQuery, sizeof szQuery, "SELECT SUM(buy_price), (SELECT SUM(money) FROM %splayers)  FROM %sboughts", szPrefix, szPrefix);
	g_hDatabase.Query(SQL_Callback_Sum, szQuery);

	Shop_AddToFunctionsMenu(FunctionDisplay, FunctionSelect);
}

void SQL_Callback_Sum(Database hDatabase, DBResultSet hResults, const char[] szError, int iClient)
{
	if szError[0] *then
	{
		LogError("SQL_Callback_Sum: %s", szError);

		return;
	}

	if SQL_FetchRow(hResults) *then
	{
		g_iMoney[0] = hResults.FetchInt(0);
		g_iMoney[1] = hResults.FetchInt(1);
	}
}

int FunctionDisplay(int iClient, char[] buffer, int maxlength)
{
	strcopy(buffer, maxlength, "Statistics");
}

bool FunctionSelect(int iClient)
{
	Panel hPanel = new Panel();

	static char szBuffer[512];

	FormatEx(szBuffer, sizeof szBuffer, "Server statistics \n \nPlayer credits: %i \nCredits spent by players: %i \n \nCredits earned by players today: %i \nCredits spent by players today: %i \n \nCredits earned by you today: %i \nCredits spent by you today: %i \n \n ", g_iMoney[1], g_iMoney[0], g_iDynamic[1], g_iDynamic[0], g_iPlayerMoney[iClient][1], g_iPlayerMoney[iClient][0]);
	SetPanelTitle(hPanel, szBuffer);

	SetPanelCurrentKey(hPanel, 7);
	DrawPanelItem(hPanel, "Back");

	SetPanelCurrentKey(hPanel, 9);
	DrawPanelItem(hPanel, "Exit");

	SendPanelToClient(hPanel, iClient, CallBack_Panel, MENU_TIME_FOREVER);

	delete hPanel;

	return true;
}

int CallBack_Panel(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if eAction == MenuAction_Select && iItem == 7 *then
	{
		Shop_ShowFunctionsMenu(iClient);
	}

	return 0;
}

public Action Shop_OnCreditsSet(int iClient, int &iCredits, int iBy_who)
{
	int iDifference, iPCredits = Shop_GetClientCredits(iClient);

	if iCredits > iPCredits *then
	{
		iDifference = iCredits - iPCredits;

		g_iMoney[1] += iDifference;

		g_iDynamic[1] += iDifference;
		g_iDynamic[0] = g_iDynamic[0] - iDifference > 0 ? g_iDynamic[0] - iDifference : 0;

		g_iPlayerMoney[iClient][1] += iDifference;
		g_iPlayerMoney[iClient][0] = g_iPlayerMoney[iClient][0] - iDifference > 0 ? g_iPlayerMoney[iClient][0] - iDifference : 0;
	}
	else
	{
		iDifference = iPCredits - iCredits;

		g_iMoney[0] += iDifference;

		g_iDynamic[1] = g_iDynamic[1] - iDifference > 0 ? g_iDynamic[1] - iDifference : 0;
		g_iDynamic[0] += iDifference;

		g_iPlayerMoney[iClient][1] = g_iPlayerMoney[iClient][1] - iDifference > 0 ? g_iPlayerMoney[iClient][1] - iDifference : 0;
		g_iPlayerMoney[iClient][0] += iDifference;
	}
}

public Action Shop_OnCreditsGiven(int iClient, int &iCredits, int iBy_who)
{
	g_iMoney[1] += iCredits;

	g_iDynamic[1] += iCredits;
	g_iDynamic[0] = g_iDynamic[0] - iCredits > 0 ? g_iDynamic[0] - iCredits : 0;

	g_iPlayerMoney[iClient][1] += iCredits;
	g_iPlayerMoney[iClient][0] = g_iPlayerMoney[iClient][0] - iCredits > 0 ? g_iPlayerMoney[iClient][0] - iCredits : 0
}

public Action Shop_OnCreditsTaken(int iClient, int &iCredits, int iBy_who)
{
	g_iMoney[1] -= iCredits;
	g_iMoney[0] += iCredits;

	g_iDynamic[1] = g_iDynamic[1] - iCredits > 0 ? g_iDynamic[1] - iCredits : 0;
	g_iDynamic[0] += iCredits;

	g_iPlayerMoney[iClient][1] = g_iPlayerMoney[iClient][1] - iCredits > 0 ? g_iPlayerMoney[iClient][1] - iCredits : 0;
	g_iPlayerMoney[iClient][0] += iCredits;
}

void ClearTime()
{
	g_iTime = (g_iTime - (g_iTime % 86400)) + 86400;
}