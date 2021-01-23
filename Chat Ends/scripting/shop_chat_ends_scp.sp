
#pragma semicolon 1
#include <sourcemod>
#include <shop>
#include <scp>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[Shop] Chat ends (CS:GO)",
	author = "ღ λŌK0ЌЭŦ ღ ™",
	description = "Set ends for chat",
	version = "1.0",
	url = "http://www.myktm.ru"
};

enum
{
	NAME_COLOR = 0,
	TEXT_COLOR,
	PREFIX_COLOR,
	PREFIX,

	SIZE
}

CategoryId g_iCategory_id[SIZE] = {INVALID_CATEGORY, ...};
bool g_bIgnoreTriggers;
Handle g_hCookie;

char g_sClientColors[MAXPLAYERS+1][3][16];
char g_sClientPrefix[MAXPLAYERS+1][64];
bool g_bClientPrefix[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_hCookie = RegClientCookie("Shop_Chat_Prefix", "Shop_Chat_Prefix", CookieAccess_Private);
	
	RegConsoleCmd("sm_tagend", SetChatTag_CMD);

	if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void Shop_Started()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	KeyValues hKeyValues = new KeyValues("Chat");
	
	Shop_GetCfgFile(sBuffer, sizeof(sBuffer), "chat.txt");
	
	if (!hKeyValues.ImportFromFile(sBuffer)) SetFailState("Не удалось открыть файл '%s'", sBuffer);

	bool category_enable[SIZE];
	char sName[64], sDescription[128];
	g_bIgnoreTriggers = view_as<bool>(hKeyValues.GetNum("ignore_ends_triggers"));

	category_enable[PREFIX_COLOR] = view_as<bool>(hKeyValues.GetNum("ends_color_enable"));
	if(category_enable[PREFIX_COLOR])
	{
		hKeyValues.GetString("ends_color_name", sName, sizeof(sName));
		hKeyValues.GetString("ends_color_description", sDescription, sizeof(sDescription));
		g_iCategory_id[PREFIX_COLOR] = Shop_RegisterCategory("chat_ends_color", sName, sDescription);
	}

	category_enable[PREFIX] = view_as<bool>(hKeyValues.GetNum("ends_enable"));

	if(category_enable[PREFIX])
	{
		hKeyValues.GetString("ends_name", sName, sizeof(sName));
		hKeyValues.GetString("ends_description", sDescription, sizeof(sDescription));
		g_iCategory_id[PREFIX] = Shop_RegisterCategory("chat_ends", sName, sDescription);

		hKeyValues.Rewind();
		if(hKeyValues.JumpToKey("Ends") && hKeyValues.GotoFirstSubKey())
		{
			do
			{
				hKeyValues.GetSectionName(sBuffer, sizeof(sBuffer));
				if (Shop_StartItem(g_iCategory_id[PREFIX], sBuffer))
				{
					hKeyValues.GetString("end", sDescription, sizeof(sDescription));
					hKeyValues.GetString("name", sName, sizeof(sName), sDescription);

					Shop_SetInfo(sName, "", hKeyValues.GetNum("price"), hKeyValues.GetNum("sellprice", -1), Item_Togglable, hKeyValues.GetNum("duration"));

					Shop_SetCallbacks(_, OnItemUsed);
					Shop_SetCustomInfoString("end", sDescription);
					Shop_EndItem();
				}
			} while (hKeyValues.GotoNextKey());
		}
	}

	hKeyValues.Rewind();
	if(hKeyValues.JumpToKey("Colors") && hKeyValues.GotoFirstSubKey())
	{
		int i;
		do
		{
			hKeyValues.GetSectionName(sBuffer, sizeof(sBuffer));
			for(i = 0; i < 3; ++i)
			{
				if(category_enable[i])
				{
					if (Shop_StartItem(g_iCategory_id[i], sBuffer))
					{
						hKeyValues.GetString("color", sDescription, sizeof(sDescription));
						hKeyValues.GetString("name", sName, sizeof(sName), sDescription);

						Shop_SetInfo(sName, "", hKeyValues.GetNum("price"), hKeyValues.GetNum("sellprice", -1), Item_Togglable, hKeyValues.GetNum("duration"));
						Shop_SetCallbacks(_, OnItemUsed);
						Shop_SetCustomInfoString("color", sDescription);
						Shop_EndItem();
					}
				}
			}
		} while (hKeyValues.GotoNextKey());
	}
	
	delete hKeyValues;
}

public ShopAction OnItemUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	int index;
	
	if(category_id == g_iCategory_id[PREFIX])
	{
		index = PREFIX;
	}
	else if(category_id == g_iCategory_id[NAME_COLOR])
	{
		index = NAME_COLOR;
	}
	else if(category_id == g_iCategory_id[TEXT_COLOR])
	{
		index = TEXT_COLOR;
	}
	else if(category_id == g_iCategory_id[PREFIX_COLOR])
	{
		index = PREFIX_COLOR;
	}

	if (isOn || elapsed)
	{
		if(index == PREFIX)
		{
			Shop_GetItemCustomInfoString(item_id, "end", g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]));
			if(strcmp(g_sClientPrefix[iClient], "custom_end") == 0)
			{
				g_bClientPrefix[iClient] = false;
			}

			g_sClientPrefix[iClient][0] = 0;
		}
		else
		{
			g_sClientColors[iClient][index][0] = 0;
		}
		return Shop_UseOff;
	}

	Shop_ToggleClientCategoryOff(iClient, category_id);
	
	if(index == PREFIX)
	{
		Shop_GetItemCustomInfoString(item_id, "end", g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]));
		if(strcmp(g_sClientPrefix[iClient], "custom_end") == 0)
		{
			GetClientCookie(iClient, g_hCookie, g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]));
			g_bClientPrefix[iClient] = true;
			PrintToChat(iClient, " \x04[SHOP] \x01To change/settings, enter !tagend \"Your ending\"");
		}
	}
	else
	{
		Shop_GetItemCustomInfoString(item_id, "color", g_sClientColors[iClient][index], sizeof(g_sClientColors[][]));
		ReplaceStringColors(g_sClientColors[iClient][index], sizeof(g_sClientColors[][]));
	}

	return Shop_UseOn;
}

void ReplaceStringColors(char[] sMessage, int iMaxLen)
{
	ReplaceString(sMessage, iMaxLen, "{DEFAULT}",		"\x01", false);
	ReplaceString(sMessage, iMaxLen, "{RED}",			"\x02", false);
	ReplaceString(sMessage, iMaxLen, "{TEAM}",			"\x03", false);
	ReplaceString(sMessage, iMaxLen, "{GREEN}",			"\x04", false);
	ReplaceString(sMessage, iMaxLen, "{LIME}",			"\x05", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTGREEN}",	"\x06", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTRED}",		"\x07", false);
	ReplaceString(sMessage, iMaxLen, "{GRAY}",			"\x08", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTOLIVE}",	"\x09", false);
	ReplaceString(sMessage, iMaxLen, "{OLIVE}",			"\x10", false);
	ReplaceString(sMessage, iMaxLen, "{PURPLE}",		"\x0E", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTBLUE}",		"\x0B", false);
	ReplaceString(sMessage, iMaxLen, "{BLUE}",			"\x0C", false);
}

public Action OnChatMessage(int &iClient, char[] sName, char[] sMessage, Handle &hRecipients)
{
	if(g_bIgnoreTriggers &&
		(sMessage[0] == '!' ||
		sMessage[0] == '/' ||
		sMessage[0] == '@'))
	{
		return Plugin_Continue;
	}
	
	if(g_sClientColors[iClient][PREFIX_COLOR][0]
	|| g_sClientPrefix[iClient][0])
	{
		if(g_sClientColors[iClient][TEXT_COLOR][0])
		{
			Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", g_sClientColors[iClient][TEXT_COLOR], sMessage);
		}
		
		if(g_sClientColors[iClient][NAME_COLOR][0])
		{
			Format(sName, MAXLENGTH_NAME, "%s%s", g_sClientColors[iClient][NAME_COLOR], sName);
		}
		else
		{
			Format(sName, MAXLENGTH_NAME, "\x03%s", sName);
		}
	
		if(g_sClientPrefix[iClient][0])
		{
			if(g_sClientColors[iClient][PREFIX_COLOR][0])
			{
				Format(sMessage, MAXLENGTH_MESSAGE, " %s%s %s", sMessage, g_sClientColors[iClient][PREFIX_COLOR], g_sClientPrefix[iClient]);
			}
			else
			{
				Format(sMessage, MAXLENGTH_MESSAGE, " \x01%s %s", sMessage, g_sClientPrefix[iClient]);
			}
		}
		else
		{
			Format(sMessage, MAXLENGTH_MESSAGE, " %s", sMessage);
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int iClient)
{
	g_sClientColors[iClient][0][0] =
	g_sClientColors[iClient][1][0] =
	g_sClientColors[iClient][2][0] =
	g_sClientPrefix[iClient][0] = 0;
	g_bClientPrefix[iClient] = false;
}

public Action SetChatTag_CMD(int iClient, int iArgs)
{
	if(iClient) 
	{
		if(g_bClientPrefix[iClient]) 
		{
			char sBuffer[128];
			GetCmdArgString(sBuffer, sizeof(sBuffer));
			TrimString(sBuffer);
			StripQuotes(sBuffer);
			if(sBuffer[0])
			{
				SetClientCookie(iClient, g_hCookie, sBuffer);
				strcopy(g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]), sBuffer);
				PrintToChat(iClient, " \x04[SHOP] \x01Вы установили себе окончание сообщения \"%s\".", sBuffer);
			}
		}
		else
		{
			PrintToChat(iClient, " \x04[SHOP] \x02Чтобы его использовать \x01окончание сообщения \x02приобретите его в магазине!");
		}
	}
	return Plugin_Handled;
}