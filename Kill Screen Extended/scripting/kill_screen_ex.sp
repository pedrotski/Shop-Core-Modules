#if SOURCEMOD_V_MINOR < 9
	#error This plugin can only compile on SourceMod 1.9+. Support: devengine.tech
#endif

#include <sourcemod>
#include <clientprefs>
#include <devcolors>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 4

public Plugin myinfo = 
{
	name = "Kill Screen Extended",
	author = "JDW",
	version = "1.1",
	url = "devengine.tech"
};

const int COLORS = 4;

const int FIELDS = 3;

const int ITEMS = 7;

const int MIN_TRANSPARENCY = 10;

static const char settings[][] =
{
	"KSE_STATUS",
	"KSE_COLORS",
	"KSE_DURATION"
};

static const char settingsMenu[][] = 
{
	"STATUS",
	"ADD_OR_SUB",
	"DURATION",
	"RED",
	"GREEN",
	"BLUE",
	"ALPHA",
};

enum 
{
    Red,
    Green,
    Blue,
    Alpha
}

enum 
{
	Status,
	Colors,
	Duration
}

enum 
{
	MIN,
	MAX
}

enum 
{
	ADD,
	SUB
}

bool pEnable[MAXPLAYERS + 1],
	 pAccess[MAXPLAYERS + 1],
	 privateMode;

int pColors[MAXPLAYERS + 1][COLORS],
	pDuration[MAXPLAYERS + 1],
	pAddOrSub[MAXPLAYERS + 1],
	duration[2];

Handle pCookie[FIELDS];

Menu gMenu;

int options[] = {50, 10, 5, 1, -1, -5, -10, -50};

public void OnPluginStart()
{
	LoadTranslations("kse.phrases");

	InitCookie();
	InitConVars();
	InitMenu();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			OnClientCookiesCached(i);
		}
	}

	RegConsoleCmd("sm_screen", ShowMenuCommand);

	HookEvent("player_death", Event_PlayerDeath);
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientDisconnect(i);
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int len)
{
	CreateNative("KSE_GrantAccess", Native_GrantAccess);

    RegPluginLibrary("kse");
    return APLRes_Success;
}

public int Native_GrantAccess(Handle plugin, int params)
{
	static int client;

	client = GetNativeCell(1);

	if(client && client <= MaxClients && !IsFakeClient(client))
	{
		pAccess[client] = true;
	}
	else 
	{
		return 0;
	}

	return 1;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int client;

	client = GetClientOfUserId(event.GetInt("attacker"));

	if(privateMode && !pAccess[client])
	{
		return;
	}

	if(client && !IsFakeClient(client) && pEnable[client])
	{
		PerformFade(client);
	}
}

public void OnClientCookiesCached(int client)
{
	char buffer[18], c[4][8];

	pAddOrSub[client] = 0;

	for(int i; i < FIELDS; i++)
	{
		GetClientCookie(client, pCookie[i], buffer, 18);
		
		switch(i)
		{
			case Status:
			{
				pEnable[client] = buffer[0] == '1';
			}
			case Colors:
			{
				ExplodeString(buffer, " ", c, 4, 8);

				for(int j; j < COLORS; j++)
				{
					pColors[client][j] = StringToInt(c[j]);

					if(j == Alpha && pColors[client][Alpha] < MIN_TRANSPARENCY)
					{
						pColors[client][Alpha] = MIN_TRANSPARENCY;
					}
				}
			}
			case Duration:
			{
				int num = StringToInt(buffer);
				pDuration[client] = num ? num : duration[MIN];
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		char buffer[18], c[4][8];

		for(int i; i < FIELDS; i++)
		{
			switch(i)
			{
				case Status:
				{
					buffer[0] = '0' + view_as<char>(pEnable[client]);
				}
				case Colors:
				{
					for(int j; j < COLORS; j++)
					{
						IntToString(pColors[client][j], c[j], 8);
					}

					ImplodeStrings(c, 4, " ", buffer, 18);
				}
				case Duration:
				{
					IntToString(pDuration[client], buffer, 18);
				}
			}

			SetClientCookie(client, pCookie[i], buffer);
		}

		pAccess[client] = false;
	}
}

public int Handler_ShowMenu(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Display:
		{
			menu.SetTitle("%T by JDW\n \n", "MENU_TITLE", client);
		}
		case MenuAction_DisplayItem:
		{
			char buffer[128];
			
			switch(item)
			{
				case 0: 
				{
					FormatEx(buffer, 128, "%T: %T\n \n", settingsMenu[item], client, pEnable[client] ? "ENABLED" : "DISABLED", client);
				}
				case 1:
				{
					FormatEx(buffer, 128, "%T: %i\n \n", settingsMenu[item], client, options[pAddOrSub[client]]);
				}
				case 2:
				{
					FormatEx(buffer, 128, "%T: %i %T\n \n", settingsMenu[item], client, pDuration[client] ? pDuration[client] : duration[MIN], "MILLISECONDS", client);
				}
				default:
				{
					FormatEx(buffer, 128, "%T: %i", settingsMenu[item], client, pColors[client][item - 3]);
				}
			}

			return RedrawMenuItem(buffer);
		}
		case MenuAction_Select:
		{
			int result;

			switch(item)
			{
				case 0:
				{
					pEnable[client] = !pEnable[client];
				}
				case 1:
				{
					if(pAddOrSub[client] == sizeof(options) - 1)
					{
						pAddOrSub[client] = 0;
					}
					else 
					{
						pAddOrSub[client]++;
					}
				}
				case 2:
				{
					result = pDuration[client] + options[pAddOrSub[client]];
					
					if(result < duration[MIN])
					{
						pDuration[client] = duration[MIN];
					}
					else if(result > duration[MAX])
					{
						pDuration[client] = duration[MAX];
					}
					else 
					{
						pDuration[client] = result;
					}
				}
				default:
				{
					item = item - 3;

					result = pColors[client][item] + options[pAddOrSub[client]];

					if(result < 0)
					{
						result = 0;
					}
					else if(result > 0xFF)
					{
						result = 0xFF;
					}
					else if(item == Alpha && result < MIN_TRANSPARENCY)
					{
						result = MIN_TRANSPARENCY;
					}

					pColors[client][item] = result;
				}
			}

			if(pEnable[client])
			{
				PerformFade(client);
			}

			menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		}
	}

    return 0;
}

public Action ShowMenuCommand(int client, int args)
{
	if(privateMode && !pAccess[client])
	{
		DCPrintToChat(client, "%T", "NO_ACCESS", client);

		return Plugin_Handled;
	}

	ShowMenu(client);

	return Plugin_Handled;
}

public void CVarMinDuration(ConVar cvar, const char[] oldValue, const char[] newValue)
{ 
    duration[MIN] = cvar.IntValue;
}

public void CVarMaxDuration(ConVar cvar, const char[] oldValue, const char[] newValue)
{ 
    duration[MAX] = cvar.IntValue;
}

public void CVarPrivateMode(ConVar cvar, const char[] oldValue, const char[] newValue)
{ 
    privateMode = cvar.BoolValue;
}

void ShowMenu(const int client)
{
	gMenu.Display(client, MENU_TIME_FOREVER);
}

void PerformFade(const int client)
{
	static int clients[1];
	clients[0] = client;

	Handle fade = StartMessage("Fade", clients, 1);

	if(fade)
	{
		if(GetUserMessageType() == UM_Protobuf)
		{
			PbSetInt(fade, "duration", pDuration[client]);
			PbSetInt(fade, "hold_time", 0);
			PbSetInt(fade, "flags", 0x0001);
			PbSetColor(fade, "clr", pColors[client]);
		}
		else 
		{
			BfWriteShort(fade, pDuration[client]);
			BfWriteShort(fade, 0);
			BfWriteShort(fade, 0x0001);
			BfWriteByte(fade, pColors[client][Red]);
			BfWriteByte(fade, pColors[client][Green]);
			BfWriteByte(fade, pColors[client][Blue]);
			BfWriteByte(fade, pColors[client][Alpha]);
		}

		EndMessage();
	}
}

void InitCookie()
{
	for(int i; i < FIELDS; i++)
	{
		if(!(pCookie[i] = RegClientCookie(settings[i], "", CookieAccess_Private)))
		{
			SetFailState("Error creating cookies: %s", settings[i]);
		}
	}
}

void InitConVars()
{
	ConVar cvar;

	char buffer[128];

	FormatEx(buffer, 128, "%t", "MIN_DURATION");
    (cvar = CreateConVar("kse_min_duration", "500", buffer)).AddChangeHook(CVarMinDuration);
    duration[MIN] = cvar.IntValue;

	FormatEx(buffer, 128, "%t", "MAX_DURATION");
    (cvar = CreateConVar("kse_max_duration", "1500", buffer)).AddChangeHook(CVarMaxDuration);
    duration[MAX] = cvar.IntValue;

	FormatEx(buffer, 128, "%t", "PRIVATE_MODE");
    (cvar = CreateConVar("kse_private_mode", "0", buffer)).AddChangeHook(CVarPrivateMode);
    privateMode = cvar.BoolValue;

	AutoExecConfig(true, "kill_screen_ex");
}

void InitMenu()
{
	gMenu = new Menu(Handler_ShowMenu, MenuAction_Select | MenuAction_Display | MenuAction_DisplayItem);
	
	for(int i; i < ITEMS; i++)
	{
		gMenu.AddItem("", "");
	}
}