#include <sourcemod>
#include <csgo_colors>
#include <shop>

public Plugin myinfo = 
{
	name = "[SHOP] Kills Change",
	author = "Drimer",
	description = "",
	version = "1.0",
	url = "http://spartdrim.ru"
};

Handle g_hKV;
int g_iMKB;
StringMap g_hMKBInfo;


public void OnPluginStart()
{
	RegConsoleCmd("sm_kc", kc); 
	if (Shop_IsStarted()) Shop_Started();
	g_hMKBInfo = new StringMap();
}

public Shop_Started()
{
	Shop_AddToFunctionsMenu(FunctionDisplay, FunctionSelect);
}

public FunctionDisplay(iClient, String:buffer[], maxlength)
{
	strcopy(buffer, maxlength, "Exchange kills for credits");
}

public bool FunctionSelect(iClient)
{
	FragMain(iClient);

	return true;
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart()
{
	g_hMKBInfo.Clear();

	KFG_Load();
}

void FragMain(int iClient)
{
	Menu hMenu = new Menu(KC);
	hMenu.SetTitle("Exchanger");
	int getfrags = GetClientFrags(iClient);
	char szBuffer[128], STIGroups[16], sBuffer[128], sBufs[3][64],sName[64];
		for(int i = 0, iKills; i <= g_iMKB; ++i)
		{
			IntToString(i, STIGroups, 16);
			g_hMKBInfo.GetString(STIGroups, sBuffer, 128);
			ExplodeString(sBuffer, ";", sBufs, 3, 64);
			strcopy(sName, 64, sBufs[0]);
			iKills = StringToInt(sBufs[2]);
			if(getfrags >= iKills) hMenu.AddItem(sBuffer, sName);
			else
			{
				
				FormatEx(szBuffer, 128, "%s [%i kills]", sName, iKills);
				hMenu.AddItem(sBuffer, szBuffer, ITEMDRAW_DISABLED);
			}
		}
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public Action kc(int iClient, int args)
{
	Menu hMenu = new Menu(KC);
	hMenu.SetTitle("Exchanger");
	int getfrags = GetClientFrags(iClient);
	char szBuffer[128], STIGroups[16], sBuffer[128], sBufs[3][64],sName[64];
		for(int i = 0, iKills; i <= g_iMKB; ++i)
		{
			IntToString(i, STIGroups, 16);
			g_hMKBInfo.GetString(STIGroups, sBuffer, 128);
			ExplodeString(sBuffer, ";", sBufs, 3, 64);
			strcopy(sName, 64, sBufs[0]);
			iKills = StringToInt(sBufs[2]);
			if(getfrags >= iKills) hMenu.AddItem(sBuffer, sName);
			else
			{
				
				FormatEx(szBuffer, 128, "%s [%i kills]", sName, iKills);
				hMenu.AddItem(sBuffer, szBuffer, ITEMDRAW_DISABLED);
			}
		}
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public KC(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_Select:
		{
					int getfrags = GetClientFrags(iClient);
					char sInfo[128];
					hMenu.GetItem(iItem, sInfo, 128);
					if(sInfo[0])
					{
						char sBufs[3][64], sName[64];
						int iCredits, iKills;
						ExplodeString(sInfo, ";", sBufs, 3, 64);
						strcopy(sName, 64, sBufs[0]);
						iCredits = StringToInt(sBufs[1]);
						iKills = StringToInt(sBufs[2]);
						SetEntProp(iClient, Prop_Data, "m_iFrags", getfrags - iKills);
						CGOPrintToChat(iClient,"Exchange completed successfully.")
						Shop_GiveClientCredits(iClient,iCredits,IGNORE_FORWARD_HOOK);
					}
		}
		case MenuAction_End: delete hMenu;
	}
}

void KFG_Load()
{
	if(g_hKV) delete g_hKV;
	char buffer[PLATFORM_MAX_PATH], g[64], STIGroups[16], sBuffer[128], sName[64];
	int iCredits, iKills;
	g_hKV = CreateKeyValues("killchange");
	BuildPath(Path_SM, buffer, sizeof buffer, "configs/shopkillchange.ini");
	FileToKeyValues(g_hKV, buffer);
	KvRewind(g_hKV);
	KvJumpToKey(g_hKV,"change", false);
	KvGotoFirstSubKey(g_hKV, true);
	g_iMKB = -1;
	do 
	{
		if (KvGetSectionName(g_hKV, g, 64))
		{
			
			++g_iMKB;
			IntToString(g_iMKB, STIGroups, 16);
			KvGetString(g_hKV, "name", sName, 64);
			iCredits = KvGetNum(g_hKV, "credits");
			iKills = KvGetNum(g_hKV, "kills");
			FormatEx(sBuffer, 128, "%s;%i;%i", sName, iCredits, iKills);
			g_hMKBInfo.SetString(STIGroups, sBuffer);
		}
	} while (KvGotoNextKey(g_hKV, true));
}