#include <sourcemod>
#include <shop>
#include <morecolors>

new shop_value = 1;

public Plugin:myinfo = {
	name = "[Shop] Frags GhostCap Edition",
	author = "RiseFallin, GhostCap Gaming", 
	url = "http://mystery-css.ru"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_frags", FragMenu);
}

public Action:FragMenu(client, iArgs)
{
	if(IsClientInGame(client))
	{
		new Handle:menu = CreateMenu(HandlerMenuFrag);
		decl String:display[128];
		SetMenuTitle(menu, "1 Kill = %d Credits:", client, shop_value);
		Format(display, sizeof(display), "Sell All Kills", client);
		AddMenuItem(menu, "fragall", display);
		
		Format(display, sizeof(display), "Sell 1 Kill", client);
		AddMenuItem(menu, "frag1", display);
		
		Format(display, sizeof(display), "Sell 5 Kills", client);
		AddMenuItem(menu, "frag5", display);
		
		Format(display, sizeof(display), "Sell 10 Kills", client);
		AddMenuItem(menu, "frag10", display);
		
		Format(display, sizeof(display), "Sell 15 Kills", client);
		AddMenuItem(menu, "frag15", display);
		
		Format(display, sizeof(display), "Sell 20 Kills", client);
		AddMenuItem(menu, "frag20", display);
		
		Format(display, sizeof(display), "Sell 50 Kills", client);
		AddMenuItem(menu, "frag50", display);
		
		Format(display, sizeof(display), "Sell 100 Kills", client);
		AddMenuItem(menu, "frag100", display);
		
		SetMenuExitButton(menu, true);
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
		return;
}

public HandlerMenuFrag(Handle:menu, MenuAction:action, client, param2)
{
	if(action==MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		if(IsClientInGame(client))
		{
			new amountfrags;
			new getfrags = GetClientFrags(client);
			new scrd;
			if(StrEqual(info, "fragall"))
			{
				amountfrags = GetClientFrags(client);
				scrd = shop_value * amountfrags;
				if(getfrags > 0)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					if(GetEntProp(client, Prop_Data, "m_iDeaths") > 0)
					{
						SetEntProp(client, Prop_Data, "m_iDeaths", 0);
						CPrintToChat(client, "{gray}Your deaths have been cleared, enjoy the game!");
					}
					Shop_GiveClientCredits(client,scrd,false);
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
			else if(StrEqual(info, "frag1"))
			{
				amountfrags = 1;
				scrd = shop_value * amountfrags;
				if(getfrags >= amountfrags)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					Shop_GiveClientCredits(client,scrd,false);
					
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
			else if(StrEqual(info, "frag5"))
			{
				amountfrags = 5;
				scrd = shop_value * amountfrags;
				if(getfrags >= amountfrags)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					Shop_GiveClientCredits(client,scrd,false);
					
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
			else if(StrEqual(info, "frag10"))
			{
				amountfrags = 10;
				scrd = shop_value * amountfrags;
				if(getfrags >= amountfrags)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					Shop_GiveClientCredits(client,scrd,false);
					
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
			else if(StrEqual(info, "frag15"))
			{
				amountfrags = 15;
				scrd = shop_value * amountfrags;
				if(getfrags >= amountfrags)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					Shop_GiveClientCredits(client,scrd,false);
					
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
			else if(StrEqual(info, "frag20"))
			{
				amountfrags = 20;
				scrd = shop_value * amountfrags;
				if(getfrags >= amountfrags)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					Shop_GiveClientCredits(client,scrd,false);
					
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
			else if(StrEqual(info, "frag50"))
			{
				amountfrags = 50;
				scrd = shop_value * amountfrags;
				if(getfrags >= amountfrags)
				{
					CPrintToChat(client, "{white}You exchanged {darkred}%i{white} kills and got {darkblue}%i{white} credits!", amountfrags, scrd);
					SetEntProp(client, Prop_Data, "m_iFrags", getfrags -= amountfrags);
					Shop_GiveClientCredits(client,scrd,false);
					
					return;
				}
				else
				{
					CPrintToChat(client, "{white}You don't have enough kills to exchange!");
					return;
				}
			}
		}
		else
			return;
	}
	if(action==MenuAction_End)
		CloseHandle(menu);
}