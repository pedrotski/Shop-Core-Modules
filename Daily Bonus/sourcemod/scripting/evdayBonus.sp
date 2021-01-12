#undef REQUIRE_PLUGIN
#tryinclude <shop>
#tryinclude <vip_core>
#define REQUIRE_PLUGIN

#include <sourcemod>

#define PL_NAME "[CS:GO] Everyday Random Bonus"
#define PL_AUTHOR "wAries, Hlmod"
#define PL_DESCRIPT "Выдает определенный рандомный бонус раз в день"
#define PL_VERSION "1.3a"
#define PL_URL "github.com/nullent"

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1
#define CustomToString(%0,%1,%2) IntToString(view_as<int>(%0), %1, %2)
#define StringToCustom(%0,%1) view_as<%0>(StringToInt(%1))
#define TABLE "CREATE TABLE IF NOT EXISTS `evdbonus` (\
							`auth` VARCHAR(64) NOT NULL PRIMARY KEY, \
							`name` VARCHAR(64) NOT NULL, \
							`timend` INTEGER UNSIGNED NOT NULL default 0, \
							`info` VARCHAR(16) NOT NULL DEFAULT 'unknown')"
Database	db;

char g_cColorsTag[][] = {"{WHITE}", "{RED}", "{LIME}", "{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", "{LIGHTOLIVE}", "{OLIVE}", "{LIGHTBLUE}", "{BLUE}", "{PURPLE}"}, \
	g_cColorsCSGO[][] = {"\x01", "\x02", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E"};
int	g_iColorsCSSOB[] = {0xFFFFFF, 0xFF0000, 0x00FF00, 0x99FF99, 0xFF4040, 0xCCCCCC, 0xFFBD6B, 0xFA8B00, 0x99CCFF, 0x3D46FF, 0xFA00FA};

EngineVersion eGame;
int iEnd[MAXPLAYERS+1];
bool IsCredits, IsVip;
int iCredits[2];

enum VIP_Set
{
	iRange[2],
	String:sGroup[64]
};

int vsBonus[VIP_Set];
bool zeroNow;
int DAY;
bool Multiple;

public Plugin myinfo =
{
	name = PL_NAME,
	author = PL_AUTHOR,
	description = PL_DESCRIPT,
	version = PL_VERSION,
	url = PL_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("VIP_GiveClientVIP");
	return APLRes_Success;
}

public void OnPluginStart()
{
	eGame = GetEngineVersion();
	LoadTranslations("everydaybonus.phrases");
	RegConsoleCmd("sm_bonus", CmdGift);

	HookEvent("round_start", OnSpawn);

	DB_Connect();
}

bool CCP;

public void OnLibraryAdded(const char[] name)
{
	if(!strcmp(name, "ccprocessor"))
		CCP = true;
}

public Action CmdGift(int iClient, int iArgs)
{
	if(!iClient || !IsClientInGame(iClient) || iEnd[iClient] == -1)
		return Plugin_Handled;
	
	SendMenu(iClient).Display(iClient, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

void DB_Connect()
{
	Database.Connect(OnBaseConnected, "evd_bonus");
}

public void OnBaseConnected(Database hdb, const char[] error, any data)
{
	if(hdb == null || error[0])
	{
		LogError("Database connect failed: %s", error);
		return;
	}

	db = hdb;
	db.SetCharset("utf8mb4");

	char Ind[4];
	db.Driver.GetIdentifier(Ind, sizeof(Ind));

	char szTable[512];
	getTablebyDriver(Ind, szTable, sizeof(szTable));
	
	db.Format(szTable, sizeof(szTable), szTable);
	db.Query(TableCreated, szTable);
}

public void TableCreated(Database hdb, DBResultSet hResult, const char[] error, any data)
{
	if(hResult == null || error[0])
		LogError("Database create failed: %s", error);
}

void getTablebyDriver(const char[] szdriver, char[] szQuery, int iLen)
{
	strcopy(szQuery, iLen, TABLE);
	if(szdriver[0] != 'm')
		ReplaceString(szQuery, iLen, "AUTO_INCREMENT", "AUTOINCREMENT");
}

public void OnMapStart()
{
	char szPath[PMP];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/evdaybonus.ini");
	ReadConfig(szPath);
}

public void OnConfigsExecuted()
{
	if(IsVip && !LibraryExists("vip_core")) IsVip = !IsVip;
	if(IsCredits && !LibraryExists("shop")) IsCredits = !IsCredits;
}

void ReadConfig(const char[] szPath)
{
	if(!FileExists(szPath))
		SetFailState("Where is my config: %s", szPath);

	SMCParser smParser = new SMCParser();
	smParser.OnKeyValue = OnKeyValueRead;

	int iLine;
	SMCError smError = smParser.ParseFile(szPath, iLine);

	if(smError != SMCError_Okay)
	{
		char sError[PMP];
		SMC_GetErrorString(smError, sError, sizeof(sError));
		LogError("Error on parse file: | %s | on | %d | line", szPath, iLine);
	}
}

SMCResult OnKeyValueRead(SMCParser SMC, const char[] sKey, const char[] sValue, bool bKey_quotes, bool bValue_quotes)
{
	if(!sKey[0] || !sValue[0])
		return SMCParse_Continue;

	if(!strcmp(sKey, "EnableCredits"))
		IsCredits = StringToCustom(bool, sValue);
	else if(!strcmp(sKey, "EnableVIP"))
		IsVip = StringToCustom(bool, sValue);
	else if(!strcmp(sKey, "minCredits"))
		iCredits[0] = StringToInt(sValue);
	else if(!strcmp(sKey, "maxCredits"))
		iCredits[1] = StringToInt(sValue);
	else if(!strcmp(sKey, "minTime"))
		vsBonus[iRange][0] = StringToInt(sValue);
	else if(!strcmp(sKey, "maxTime"))
		vsBonus[iRange][1] = StringToInt(sValue);
	else if(!strcmp(sKey, "groupVIP"))
		strcopy(vsBonus[sGroup], 64, sValue);
	else if(!strcmp(sKey, "zeroBonus"))
		zeroNow = StringToCustom(bool, sValue);
	else if(!strcmp(sKey, "Period"))
		DAY = StringToInt(sValue);
	else if(!strcmp(sKey, "Multiple"))
		Multiple = StringToCustom(bool, sValue);
	
	return SMCParse_Continue;
}

bool sendedOnThisSession[MAXPLAYERS+1];

public void OnClientPutInServer(int iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	sendedOnThisSession[iClient] = false;
	iEnd[iClient] = -1;
	
	char szSteam[64];
	GetClientAuthId(iClient, AuthId_Engine, szSteam, sizeof(szSteam));

	loadInfoFromBase(iClient, szSteam);
}

void loadInfoFromBase(int iClient, const char[] szSteam)
{
	char szQuery[512];
	db.Format(szQuery, sizeof(szQuery), "SELECT `timend` FROM `evdbonus` WHERE `auth` = '%s'", szSteam);
	db.Query(OnQueryResult, szQuery, GetClientUserId(iClient));
}

public void OnQueryResult(Database hdb, DBResultSet hResult, const char[] error, any data)
{
	if(error[0])
		SetFailState("Failed on user fetched: %s", error);
	
	data = GetClientOfUserId(data);
	if(!data || !IsClientInGame(data))
		return;

	if(hResult.FetchRow())
		iEnd[data] = hResult.FetchInt(0);
	else newRow(data);
}

void newRow(int iClient)
{
	char szSteam[64], szQuery[512], szName[32];
	GetClientAuthId(iClient, AuthId_Engine, szSteam, sizeof(szSteam));
	GetClientName(iClient, szName, sizeof(szName));

	char szEsName[65];
	db.Escape(szName, szEsName, sizeof(szEsName));

	db.Format(szQuery, sizeof(szQuery), "INSERT INTO `evdbonus` (`name`, `auth`) VALUES ('%s', '%s')", szEsName, szSteam);
	db.Query(OnNewRow, szQuery, GetClientUserId(iClient));
}

public void OnNewRow(Database hdb, DBResultSet hResult, const char[] error, any data)
{
	if(hResult == null || error[0])
		SetFailState("Failed on write row: %s", error);
	
	data = GetClientOfUserId(data);
	if(!data || !IsClientInGame(data))
		return;
	
	char szSteam[64]
	GetClientAuthId(data, AuthId_Engine, szSteam, sizeof(szSteam));

	loadInfoFromBase(data, szSteam);
}

public void OnSpawn(Event ev, const char[] name, bool dBroad)
{
	static int iTime;
	iTime = GetTime();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || sendedOnThisSession[i] || iEnd[i] > iTime)
			continue;

		SendColorMsg(i, "%t", "evd_bonusactive");
		sendedOnThisSession[i] = true;
	}
}

Menu SendMenu(int iClient)
{
	int iTime = GetTime();

	char szTime[32] = "Available";
	if(iTime < iEnd[iClient])
		GetStringTime(iEnd[iClient] - iTime, szTime, sizeof(szTime));
		
	Menu hMenu = new Menu(OnMainCallBack);
	hMenu.SetTitle("%t \n \n", "evd_title", szTime);
	hMenu.AddItem(NULL_STRING, "Get bonus", (iTime < iEnd[iClient]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	return hMenu;
}

enum TypeBonus
{
	tbNone = 0,
	tbVIP,
	tbCredits
};

public int OnMainCallBack(Menu hMenu, MenuAction action, int iClient, int iOpt)
{
	if(action == MenuAction_End)
	{
		hMenu.Close();
		return;
	}
	else if(action != MenuAction_Select)
		return;
	
	TypeBonus tbBonus = tbNone;
	bool InValid = true;

	while(InValid)
	{
		tbBonus = randomizeType();
		if((!zeroNow && tbBonus == tbNone)
		|| (!IsVip && tbBonus == tbVIP)
		|| (!IsCredits && tbBonus == tbCredits))
			continue;

		InValid = false;
	}

	randomizeByType(iClient, tbBonus);
}

void randomizeByType(int iClient, TypeBonus tbBonus)
{
	int iBonus = getRandomValue(tbBonus);

	switch(tbBonus)
	{
		case tbVIP:
		{
			if(VIP_IsClientVIP(iClient))
			{
				int iTime = VIP_GetClientAccessTime(iClient);
				if(!iTime)
				{
					if(!IsCredits) tbBonus = tbNone;
					else randomizeByType(iClient, tbCredits);
				} 
				else
				{
					iTime += iBonus*60;
					VIP_SetClientAccessTime(iClient, iTime, true);
					SendColorMsg(iClient, "%t", "evd_alreadyvip", iBonus);
				}
			}
			else VIP_GiveClientVIP(0, iClient, iBonus*60, vsBonus[sGroup], true);
		}
		case tbCredits:
		{
			int iCount = Shop_GiveClientCredits(iClient, iBonus, (Multiple) ? CREDITS_BY_NATIVE : IGNORE_FORWARD_HOOK);
			SendColorMsg(iClient, "%t", "evd_credits", iCount);
		}
	}

	SendColorMsg(iClient, "%t", (tbBonus == tbNone) ? "evd_none" : "evd_accepted");
	updateRow(iClient, tbBonus);
}

void updateRow(int iClient, TypeBonus curType)
{
	char szType[16]; szType = (curType == tbNone) ? "NONE" : (curType == tbVIP) ? "VIP" : "CREDITS";

	char szSteam[64], szName[32], szQuery[512];
	GetClientAuthId(iClient, AuthId_Engine, szSteam, sizeof(szSteam));
	GetClientName(iClient, szName, sizeof(szName));

	char szEsName[65];
	iEnd[iClient] = GetTime() + DAY;

	db.Escape(szName, szEsName, sizeof(szEsName));
	db.Format(szQuery, sizeof(szQuery), "UPDATE `evdbonus` SET `timend` = %i, `name` = '%s', `info` = '%s' WHERE `auth` = '%s'", iEnd[iClient], szEsName, szType, szSteam);
	db.Query(TableCreated, szQuery);
}

int getRandomValue(TypeBonus curType)
{
	return curType == tbVIP ? GetRandomInt(vsBonus[iRange][0], vsBonus[iRange][1]) : GetRandomInt(iCredits[0], iCredits[1]);
}

TypeBonus randomizeType()
{
	return view_as<TypeBonus>(GetRandomInt(0, 2));
}

void GetStringTime(int time, char[] buffer, int maxlength)
{
	static int dims[] = {60, 60, 24, 30, 365, cellmax};
	static char sign[][] = {"sec", "m", "h", "d", "m", "y"};
	static char form[][] = {"%02i%s%s", "%02i%s %s", "%i%s %s"};
	buffer[0] = EOS;
	int i = 0, f = -1;
	bool cond = false;
	while (!cond) 
	{
		if (f++ == 1)
			cond = true;
		do {
			Format(buffer, maxlength, form[f], time % dims[i], sign[i], buffer);
			if (time /= dims[i++], time == 0)
				return;
		} while (cond);
	}
}

void SendColorMsg(int iClient, const char[] szMsg, any ...)
{
	static char szBuffer[PMP];

	SetGlobalTransTarget(iClient);
	VFormat(szBuffer, sizeof(szBuffer), szMsg, 3);

	if(CCP) 
	{
		if(iClient) PrintToChat(iClient, szBuffer);
		else PrintToChatAll(szBuffer);
	}
	else SendMsg(iClient, szBuffer, sizeof(szBuffer));
}

void SendMsg(int iClient, char[] sMsg, int iSize)
{
	if(eGame == Engine_CSGO)
	{
		for(int i = 1; i < 11; i++)
			ReplaceString(sMsg, iSize, g_cColorsTag[i], g_cColorsCSGO[i], false);
	}
	else if(eGame == Engine_CSS)
	{
		char sBuffer[32];
		for(int i; i < 11; i++)
		{
			FormatEx(sBuffer, sizeof(sBuffer), "\x07%06X", g_iColorsCSSOB[i]);
			ReplaceString(sMsg, iSize, g_cColorsTag[i], sBuffer, false);
		}
	}
	
	ReplaceString(sMsg, iSize, "{DEFAULT}", g_cColorsCSGO[0], false);
	ReplaceString(sMsg, iSize, "{TEAM}", "\x03", false);
	ReplaceString(sMsg, iSize, "{GREEN}", "\x04", false);

	if(!iClient) PrintToChatAll(sMsg);
	else PrintToChat(iClient, sMsg);
}