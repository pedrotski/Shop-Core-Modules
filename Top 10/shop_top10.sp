#pragma semicolon 1

#include <sourcemod>
#include <shop>

#define PLUGIN_VERSION	"2.0.1"

new Handle:dp;
new String:dp_prefix[16];

public Plugin:myinfo = 
{
	name = "[Shop] Top10 Function",
	author = "FrozDark",
	description = "Adds top10 function to the shop",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

public OnPluginStart()
{
	if (Shop_IsStarted()) Shop_Started();
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public Shop_Started()
{
	dp = Shop_GetDatabase();
	Shop_GetDatabasePrefix(dp_prefix, sizeof(dp_prefix));
	
	Shop_AddToFunctionsMenu(FunctionDisplay, FunctionSelect);
}

public FunctionDisplay(client, String:buffer[], maxlength)
{
	strcopy(buffer, maxlength, "Top 10 Rich List");
}

public bool:FunctionSelect(client)
{
	decl String:query[256];
	FormatEx(query, sizeof(query), "SELECT `name`, `money` FROM `%splayers` ORDER BY `money` DESC LIMIT 10", dp_prefix);
	SQL_TQuery(dp, GetTop10, query, GetClientSerial(client));
	
	return true;
}

public GetTop10(Handle:owner, Handle:hndl, const String:error[], any:serial) 
{ 
	if (hndl == INVALID_HANDLE || error[0]) 
	{ 
		LogError("GetTop10: %s", error);
		
		return;
	}
	
	new client = GetClientFromSerial(serial);
	if (!client)
	{
		return;
	}
	
	new count = SQL_GetRowCount(hndl);
	if (count > 10)
	{
		count = 10;
	}
	else if (!count)
	{
		Shop_ShowFunctionsMenu(client);
		return;
	}
		
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "Top 10 Ballers");
	
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	DrawPanelText(panel, "-----------------------------");
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	decl String:display[128], String:name[MAX_NAME_LENGTH+1], money;
	for (new i = 1; i <= count; i++)
	{
		SQL_FetchRow(hndl);
		
		SQL_FetchString(hndl, 0, name, sizeof(name));
		money = SQL_FetchInt(hndl, 1);
		
		FormatEx(display, sizeof(display), "%i. %s [%d]", i, name, money);
		
		DrawPanelText(panel, display);
	}
	
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	DrawPanelText(panel, "-----------------------------");
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	SetPanelCurrentKey(panel, 8);
	DrawPanelItem(panel, "Back");
	
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	SetPanelCurrentKey(panel, 10);
	DrawPanelItem(panel, "Exit");
	
	SendPanelToClient(panel, client, PanelHandler, 30);
	CloseHandle(panel);
}

public PanelHandler(Handle:menu, MenuAction:action, param1, param2)
{
	switch (param2)
	{
		case 8 :
		{
			Shop_ShowFunctionsMenu(param1);
		}
	}
}