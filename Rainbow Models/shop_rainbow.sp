#include <shop>

#if SOURCEMOD_V_MINOR < 10 && SOURCEMOD_V_MINOR < 11
---> #error This plugin only compile on SM 1.10 & 1.11
#endif

int Rainbow[3], RainbowDirection = -1, RainbowPrice, SellPriceRainbow, RainbowDuration;
bool RainbowEnable[MAXPLAYERS+1];

enum
{
	RED = 0,
	GREEN,
	BLUE
}

public Plugin myinfo ={
	name = "[Shop] Rainbow Models",
    description = "Rainbow Player Models",
	author = "-=HellFire=-",
	version = "1.0",
	url = "VK: vk.com/insellx | HLMOD: hlmod.ru/members/hellfire.105029"
};

public void OnPluginStart()
{
	ConVar hCvar;

	HookConVarChange((hCvar = CreateConVar("sm_shop_rainbow_price", "1000", "Rainbow Purchase Price.")), PriceRainbow);
	RainbowPrice = hCvar.IntValue;

	HookConVarChange((hCvar = CreateConVar("sm_shop_rainbow_sellprice", "500", "Rainbow Selling Price.")), RainbowSellPrice);
	SellPriceRainbow = hCvar.IntValue;

	HookConVarChange((hCvar = CreateConVar("sm_shop_rainbow_duration", "604800", "Rainbow duration in seconds (default 1 week)")), DurationRainbow);
	RainbowDuration = hCvar.IntValue;

	AutoExecConfig(true, "shop_rainbow", "shop");

	if (Shop_IsStarted()) Shop_Started();
}

public void OnClientDisconnect(int client)
{
	RainbowEnable[client] = false;
}

public void Shop_Started()
{
    CategoryId CATEGORY = Shop_RegisterCategory("Rainbow Model", "Rainbow Model", "");

    if(CATEGORY == INVALID_CATEGORY)
    {
        SetFailState("Failed to register category");
    }

    if(Shop_StartItem(CATEGORY, "rainbow"))
    {
		Shop_SetInfo("Rainbow Model", "Add Colours To Your Model", RainbowPrice, SellPriceRainbow, Item_Togglable, RainbowDuration);
		Shop_SetCallbacks(_, OnEquipItem);
		Shop_EndItem();
    }
    else
    {
        	SetFailState("Failed to register item");
    }
}

public void OnPluginEnd()
{
    Shop_UnregisterMe();
}

public int PriceRainbow(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
    RainbowPrice = hCvar.IntValue;
}

public int RainbowSellPrice(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
    SellPriceRainbow = hCvar.IntValue;
}

public int DurationRainbow(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
    RainbowDuration = hCvar.IntValue;
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] CATEGORY, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
 	if (isOn || elapsed)
	{
        OnClientDisconnect(client);
        return Shop_UseOff;
	}
        RainbowEnable[client] = true;
        GetRainbow();

        return Shop_UseOn;
}

public void OnGameFrame()
{
	if((GetGameTickCount() % 5) == 0)
	{
		GetRainbow();
		for(int i = 1; i < MaxClients; i++)
		{
			if(!IsClientInGame(i) || !IsPlayerAlive(i))
				continue;
			if(RainbowEnable[i])
				SetEntityRenderColor(i, Rainbow[RED], Rainbow[GREEN], Rainbow[BLUE], 255);
			else
				SetEntityRenderColor(i, 255, 255, 255, 255);
		}
	}
}

void GetRainbow()
{
	switch(RainbowDirection)
	{
		case 0:
		{
			Rainbow[BLUE] += 15;

			if(Rainbow[BLUE] >= 255)
			{
				Rainbow[BLUE] = 255;
				RainbowDirection = 1;
			}
		}

		case 1:
		{
			Rainbow[RED] -= 15;

			if(Rainbow[RED] <= 180)
			{
				Rainbow[RED] = 180;
				RainbowDirection = 2;
			}
		}

		case 2:
		{
			Rainbow[GREEN] += 15;

			if(Rainbow[GREEN] >= 255)
			{
				Rainbow[GREEN] = 255;
				RainbowDirection = 3;
			}
		}

		case 3:
		{
			Rainbow[BLUE] -= 15;

			if(Rainbow[BLUE] <= 0)
			{
				Rainbow[BLUE] = 0;
				RainbowDirection = 4;
			}
		}

		case 4:
		{
			Rainbow[RED] += 15;

			if(Rainbow[RED] >= 255)
			{
				Rainbow[RED] = 255;
				RainbowDirection = 5;
			}
		}

		case 5:
		{
			Rainbow[GREEN] -= 15;

			if(Rainbow[GREEN] <= 125)
			{
				Rainbow[GREEN] = 125;
				RainbowDirection = 0;
			}
		}

		default:
		{
			Rainbow[RED] = 255;
			RainbowDirection = 0;
		}
	}
}