#include <sourcemod>
#include <shop>
#include <duck_speed>

#pragma newdecls required

#define DEFAULT_DUCK_SPEED 6.023437
#define CATEGORY "ability"
#define ITEM 	 "duck_speed"

public Plugin myinfo = 
{
	name = "[Shop] Duck Speed",
	author = "HolyHender | Credits: Wend4r",
	description = "",
	version = "1.0.1",
};

bool g_bUseDuckSpeed[MAXPLAYERS + 1];

ConVar cvar_Enable, cvar_Price, cvar_SellPrice, cvar_Duration;

ItemId id;

public void OnPluginStart()
{
    cvar_Enable = CreateConVar("sm_shop_duck_speed_enable", "1", "RU: Включена ли работа плагина\nEN: Whether the plugin is enabled", _, true, 0.0, true, 1.0);
	(cvar_Price = CreateConVar("sm_shop_duck_speed_price", "1000", "RU: Стоимость покупки Duck Speed\nEN: Price of Duck Speed")).AddChangeHook(OnConVarChange);
	(cvar_SellPrice = CreateConVar("sm_shop_duck_speed_sellprice", "800", "RU: Стоимость продажи Duck Speed\nEN: Sell price of Duck Speed")).AddChangeHook(OnConVarChange);
    (cvar_Duration = CreateConVar("sm_shop_duck_speed_duration", "86400", "RU: Длительность Duck Speed в секундах\nEN: Duration of Duck Speed in seconds")).AddChangeHook(OnConVarChange);

    AutoExecConfig(true, "duck_speed", "shop");
    LoadTranslations("shop_duck_speed.phrases");

    if (Shop_IsStarted()) Shop_Started();
}

void OnConVarChange(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
    if(id == INVALID_ITEM)
	{
		return;
	}

	if(cvar == cvar_Price) Shop_SetItemPrice(id, cvar.IntValue);
	else if(cvar == cvar_SellPrice) Shop_SetItemSellPrice(id, cvar.IntValue);
	else if(cvar == cvar_Duration) Shop_SetItemValue(id, cvar.IntValue);
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, CATEGORY, "", OnCategoryDisplay);

	if(Shop_StartItem(category_id, ITEM))
	{
		Shop_SetInfo(ITEM, "", cvar_Price.IntValue, cvar_SellPrice.IntValue, Item_Togglable, cvar_Duration.IntValue);
		Shop_SetCallbacks(OnItemRegistered, OnItemUse, _, OnItemDisplay);
		Shop_EndItem();
	}
}

public bool OnCategoryDisplay(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. Category Display", client);
	return true;
}

public bool OnItemDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. Item Display", client);
	return true;
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	id = item_id;
}

public ShopAction OnItemUse(int iClient, CategoryId category_id, const char[] sCategory, ItemId item_id, const char[] sItem, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bUseDuckSpeed[iClient] = false;
		return Shop_UseOff;
	}

	g_bUseDuckSpeed[iClient] = true;

	return Shop_UseOn;
	
}

public void OnClientDisconnect(int iClient)
{
	g_bUseDuckSpeed[iClient] = false;
}

public void OnPluginEnd() 
{
	Shop_UnregisterMe();
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	if(!cvar_Enable.BoolValue)
		return;
	
	static int iOldButtons[MAXPLAYERS + 1];

	if(g_bUseDuckSpeed[iClient] && iButtons & IN_DUCK && !(iOldButtons[iClient] & IN_DUCK))
	{
		SetDuckSpeed(iClient, DEFAULT_DUCK_SPEED);
	}
	else if(!g_bUseDuckSpeed[iClient] && iOldButtons[iClient])
	{
		SetDuckSpeed(iClient, -1.0);
	}

	iOldButtons[iClient] = iButtons;
}