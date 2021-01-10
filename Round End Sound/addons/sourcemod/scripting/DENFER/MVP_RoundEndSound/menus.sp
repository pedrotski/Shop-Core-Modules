
/* *******************************************************
 *
 *   					MAIN MENU  
 *
 * ******************************************************** */
 
public Action Menu_Music(int client, int args)
{
	Menu menu = new Menu(HandlerMenu_Music);
	char info[128];
	
	FormatEx(info, sizeof(info), "%T", "Menu_Title_Music", LANG_SERVER);
	menu.SetTitle(info);
	
	if(gc_bOffSoundMVP.BoolValue)
	{
		if(g_bMVPMusic[client])
		{
			FormatEx(info, sizeof(info), "%T", "Menu_Disable_Music", LANG_SERVER);
			menu.AddItem("disable", info);
		}
		else
		{
			FormatEx(info, sizeof(info), "%T", "Menu_Enable_Music", LANG_SERVER);
			menu.AddItem("enable", info);
		}
	}
	
	if(gc_bCustomToggleMVP.BoolValue)
	{
		FormatEx(info, sizeof(info), "%T", "Menu_Toggle_Music_Specific_Player", LANG_SERVER);
		menu.AddItem("toggle", info);
	}

	if(gc_bViewYourKits.BoolValue)
	{
		FormatEx(info, sizeof(info), "%T", "Menu_View_Music_Kits", LANG_SERVER);
		menu.AddItem("your_kits", info);
	}
	
	if(gc_bViewOtherKits.BoolValue)
	{
		FormatEx(info, sizeof(info), "%T", "Menu_View_Other_Music_Kits", LANG_SERVER);
		menu.AddItem("others_kits", info);
		
		if(g_bOther[client]) // если из просмотра чужик наборов
		{
			g_bOther[client] = false;
		}
	}
	
	if(gc_bVolume.BoolValue)
	{
		FormatEx(info, sizeof(info), "%T", "Menu_Volume", LANG_SERVER);
		menu.AddItem("volume", info);
	}
	
	if(gc_bShop.BoolValue)
	{
		FormatEx(info, sizeof(info), "%T", "Menu_Shop_Music_Kits", LANG_SERVER);
		menu.AddItem("shop", info);
		
		if(g_bBuy[client]) // если вышли из магазина
		{
			g_bBuy[client] = false;
		}
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int HandlerMenu_Music(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if(StrEqual("disable", info))
			{
				MVP_SetClientPlayMusic(param1, false);
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_MVP_Sound_Off");
				Menu_Music(param1, 0);
			}
			else if(StrEqual("enable", info))
			{
				MVP_SetClientPlayMusic(param1, true);
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_MVP_Sound_On");
				Menu_Music(param1, 0);
			}
			else if(StrEqual("toggle", info))
			{
				Menu_SwitchMusicMVP(param1);
			}
			else if(StrEqual("your_kits", info))
			{
				Menu_YourMusicKits(param1);
			}
			else if(StrEqual("others_kits", info))
			{
				Menu_OthersMusicKits_SelectPlayer(param1);
			}
			else if(StrEqual("shop", info))
			{
				Menu_Shop(param1);
			}
			else if(StrEqual("volume", info))
			{
				Menu_Volume(param1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

/* *******************************************************
 *
 *   				YOUR MUSIC KITS 
 *
 * ******************************************************** */
 
 public void Menu_YourMusicKits(int client)
 {
	Menu menu = new Menu(HandlerMenu_YourMusicKits);
	char info[128];
	
	ShowPlayerMusicKits(client, menu);
	
	FormatEx(info, sizeof(info), "%T \n%T", "Menu_Title_Your_Kits", LANG_SERVER, "Menu_Title_Your_Have_Kits", LANG_SERVER, g_iKits[client]);
	menu.SetTitle(info);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 }
 
 public int HandlerMenu_YourMusicKits(Menu menu, MenuAction action, int param1, int param2)
 {
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[128];
			menu.GetItem(param2, info, sizeof(info));

			Menu_YourComposition(param1, info);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Music(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
 }
 
 public void Menu_YourComposition(int client, char[] kit)
 {
	Menu menu = new Menu(HandlerMenu_YourComposition);
	char info[PLATFORM_MAX_PATH];
	
	FormatEx(g_sKitBuffer[client], sizeof(g_sKitBuffer[]), "%s", kit); // копируем в буфер музыкальный набор, чтоб была возможность вернуться в него
	ShowPlayerMusic(client, kit, menu);
	
	FormatEx(info, sizeof(info), "%T \n%T", "Menu_Title_Kit", LANG_SERVER, kit, "Menu_Title_Your_Have_Compositions", LANG_SERVER, g_iCompositions[client]);
	menu.SetTitle(info);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 }
 
 public int HandlerMenu_YourComposition(Menu menu, MenuAction action, int param1, int param2)
 {
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			ShowComposition(param1, info);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_YourMusicKits(param1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
 }
 
 /* *******************************************************
 *
 *   				OTHERS MUSIC KITS 
 *
 * ******************************************************** */
 
 public void Menu_OthersMusicKits_SelectPlayer(int client)
 {
	Menu menu = new Menu(HandlerMenu_OthersMusicKits_SelectPlayer);
	char info[MAX_NAME_LENGTH];
	char userid[16];
	
	FormatEx(info, sizeof(info), "%T", "Menu_Others_Music_Kits_Select_Player", LANG_SERVER);
	menu.SetTitle(info);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && !IsBotClient(i))
		{
			char kits[4]; // хранит число наборов
			IntToString(MVP_GetClientMusicKits(i), kits, sizeof(kits));
			FormatEx(info, sizeof(info), "%N [%s]", i, kits);
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			menu.AddItem(userid, info);
		}
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 }
 
  public int HandlerMenu_OthersMusicKits_SelectPlayer(Menu menu, MenuAction action, int param1, int param2)
 {
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			int target = GetClientOfUserId(StringToInt(info));
			
			if(IsValidClient(target))
			{
				Menu_OtherMusicKits(param1, target);
			}
			else
			{
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Client_Left_The_Server");
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Music(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
 }
 
  public void Menu_OtherMusicKits(int client, int target)
 {
	Menu menu = new Menu(HandlerMenu_OtherMusicKits);
	char info[128];
	g_iTarget[client] = target; // устанавливаем таргет на выбранного игрока
	
	ShowPlayerMusicKits(target, menu);

	FormatEx(info, sizeof(info), "%T \n%T", "Menu_Title_Other_Kits", LANG_SERVER, target, "Menu_Title_Other_Have_Kits", LANG_SERVER, g_iKits[target]);
	menu.SetTitle(info);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 }
 
 public int HandlerMenu_OtherMusicKits(Menu menu, MenuAction action, int param1, int param2)
 {
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[128];
			menu.GetItem(param2, info, sizeof(info));
			
			if(IsValidClient(g_iTarget[param1]))
			{
				Menu_OtherComposition(param1, g_iTarget[param1], info); 
			}
			else
			{
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Client_Left_The_Server");
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Music(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
 }
 
 public void Menu_OtherComposition(int client, int target, char[] kit)
 {
	Menu menu = new Menu(HandlerMenu_OtherComposition);
	char info[PLATFORM_MAX_PATH];
	g_bOther[client] = true; // плагин считает, что игрок просматривает чью-либо музыку
	
	FormatEx(g_sKitBuffer[client], sizeof(g_sKitBuffer[]), "%s", kit); // копируем в буфер музыкальный набор, чтоб была возможность вернуться в него, g_sKitBuffer[client] - клиент, т.к. в данном сулчае вы просматрвиаете композиции
	
	ShowPlayerMusic(target, kit, menu);
	
	FormatEx(info, sizeof(info), "%T \n%T", "Menu_Title_Other_Kit", LANG_SERVER, kit, "Menu_Title_Other_Have_Compositions", LANG_SERVER, g_iCompositions[target]); // в данном случае выведет количество композиций таргета
	menu.SetTitle(info);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 }
 
 public int HandlerMenu_OtherComposition(Menu menu, MenuAction action, int param1, int param2)
 {
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			if(IsValidClient(g_iTarget[param1]))
			{
				ShowComposition(g_iTarget[param1], info);
			}
			else
			{
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Client_Left_The_Server");
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_OtherMusicKits(param1, g_iTarget[param1]);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
 }
 
 /* *******************************************************
 *
 *   				COMPOSITION INFORMATION 
 *
 * ******************************************************** */
 
public void Panel_ShowComposition(int client, char[] name, char[] duration, char[] cost, char[] description, const char[] path)
{
	Panel panel = new Panel();
	char info[PLATFORM_MAX_PATH];
	
	FormatEx(info, sizeof(info), "%s", name); // название композиции
	panel.SetTitle(info);
	
	if(strlen(duration) != 0)
	{
		FormatEx(info, sizeof(info), "%T %s", "Panel_Duration_Composition", LANG_SERVER, duration);
		panel.DrawText(info);
	}
	else
	{
		panel.DrawText(" ");
	}
	
	if(strlen(cost) != 0)
	{
		FormatEx(info, sizeof(info), "%T %s", "Panel_Cost_Composition", LANG_SERVER, cost);
		panel.DrawText(info);
	}
	else
	{
		panel.DrawText(" ");
	}
	
	if(strlen(description) != 0)
	{
		FormatEx(info, sizeof(info), "%T %s", "Panel_Description_Composition", LANG_SERVER, description);
		panel.DrawText(info);
	}
	else
	{
		panel.DrawText(" ");
	}
	
	panel.DrawText(" ");
	
	if(strlen(path) != 0)
	{
		FormatEx(g_sPathBuffer[client], sizeof(g_sPathBuffer[]), "%s", path);
		FormatEx(info, sizeof(info), "%T", "Panel_Demo_Composition", LANG_SERVER);
		panel.DrawItem(info); // 1
	}
	
	if(strlen(path) != 0) 
	{
		FormatEx(g_sPathBuffer[client], sizeof(g_sPathBuffer[]), "%s", path);
		FormatEx(info, sizeof(info), "%T", "Panel_Stop_Demo_Composition", LANG_SERVER);
		panel.DrawItem(info); // 2
	}
	
	if(!g_bBuy[client])
	{
		panel.DrawText(" ");
	}
	else
	{
		GetMusicMethod(g_sPathBuffer[client], "link", g_sDonateLink[client], sizeof(g_sDonateLink[]));
		if(strlen(g_sDonateLink[client]) == 0)
		{
			gc_sDonateLink.GetString(g_sDonateLink[client], sizeof(g_sDonateLink[]));
		}
		FormatEx(info, sizeof(info), "%T", "Panel_Buy_Button", LANG_SERVER); 
		panel.DrawItem(info); // 3
	}
	
	FormatEx(info, sizeof(info), "%T", "Panel_ExitBackButton", LANG_SERVER); 
	panel.DrawItem(info); // 4
	
	FormatEx(info, sizeof(info), "%T", "Panel_ExitButton", LANG_SERVER); 
	panel.DrawItem(info); // 5

	panel.Send(client, HandlerPanel_ShowComposition, MENU_TIME_FOREVER);
	delete panel;
}

public int HandlerPanel_ShowComposition(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[2];
			IntToString(param2, info, sizeof(info));
			
			if(StrEqual("1", info))
			{
				if(strlen(g_sAudioPlayer) > 1) 
					StopSound(param1, SNDCHAN_AUTO, g_sAudioPlayer); // если в этот момент играет музыка MVP
					
				if(strlen(g_sPlaylist[param1]) > 1)
					StopSound(param1, SNDCHAN_AUTO, g_sPlaylist[param1]);  // g_sPlaylist - если в вашем плей-листе уже играет музыка
					
				FormatEx(g_sPlaylist[param1], sizeof(g_sPlaylist[]), "%s", g_sPathBuffer[param1]); // копируем в новую переменную на случай, если игрок решит поппрыгать по другим разделам 
				EmitSoundToClient(param1, g_sPlaylist[param1], -2, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_flVolume[param1]);
				ShowComposition(param1, g_sPathBuffer[param1]);
			}
			else if(StrEqual("2", info))
			{
				if(strlen(g_sPlaylist[param1]) > 1)
					StopSound(param1, SNDCHAN_AUTO, g_sPlaylist[param1]);
					
				ShowComposition(param1, g_sPathBuffer[param1]);
			}
			else if(StrEqual("3", info) && g_bBuy[param1])
			{
				char link[MAX_NAME_LENGTH]; gc_sDonateLink.GetString(link, sizeof(link));
				if(StrEqual(g_sDonateLink[param1], link))
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Buy_This_Product", g_sDonateLink[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Buy_This_Product", g_sDonateLink[param1]);
				}
				
				gc_sDonateLink.GetString(g_sDonateLink[param1], sizeof(g_sDonateLink[]));
				ShowComposition(param1, g_sPathBuffer[param1]);
			}
			else if((StrEqual("4", info) && g_bBuy[param1]) || (StrEqual("3", info) && !g_bBuy[param1]))
			{
				if(g_bOther[param1]) // если игрок пришел из чужого набора
				{
					Menu_OtherComposition(param1, g_iTarget[param1], g_sKitBuffer[param1]);
				}
			
				if(g_bBuy[param1]) // если пришел из магазина
				{
					Menu_ShopCompositions(param1, g_sKitBuffer[param1]);
				}
				
				if(!g_bBuy[param1]) // если это не оба случая сверху => игрок просматривает свои наборы
				{
					Menu_YourComposition(param1, g_sKitBuffer[param1]);
				}
			}
		}
	}
}
 
 /* *******************************************************
 *
 *   						SHOP
 *
 * ******************************************************** */
 
public void Menu_Shop(int client)
{
	Menu menu = new Menu(HandlerMenu_Shop);
	char info[128];
	
	FormatEx(info, sizeof(info), "%T", "Menu_Title_Shop", LANG_SERVER);
	menu.SetTitle(info);
	
	CreateShopCategory(client, menu);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
 
public int HandlerMenu_Shop(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			FormatEx(g_sKitBuffer[param1], sizeof(g_sKitBuffer[]), "%s", info); // запоминаем название раздела, чтобы вернуться в него 
			Menu_ShopCompositions(param1, info);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Music(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}
 
public void Menu_ShopCompositions(int client, const char[] name)
{
	Menu menu = new Menu(HandlerMenu_ShopCompositions);
	char info[128];
	
	CreateShopCompositions(client, menu, name);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Title_Shop_Compositions", LANG_SERVER, name, g_iShopBuffer[client]);
	menu.SetTitle(info);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandlerMenu_ShopCompositions(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			g_bBuy[param1] = true;
			ShowComposition(param1, info);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Shop(param1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

 /* *******************************************************
 *
 *   			    SWITCH MUSIC MVP
 *
 * ******************************************************** */

public void Menu_SwitchMusicMVP(int client)
{
	Menu menu = new Menu(HandlerMenu_SwitchMusicMVP);
	char info[128];
	char userid[16];
	
	int counter = 0;
	
	FormatEx(info, sizeof(info), "%T \n%T", "Menu_Title_Toggle_MVP", LANG_SERVER, "Menu_Title_Note_Toggle_MVP", LANG_SERVER);
	menu.SetTitle(info);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && !IsBotClient(i))
		{
			FormatEx(info, sizeof(info), "%N [%s]", i, g_bDisableMVPMusic[client][i] ? "x" : " ");
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			counter++;
			menu.AddItem(userid, info);
		}
	}
	
	if(!counter)
	{
		if(gc_bPluginMessage.BoolValue) CPrintToChat(client, "%s %t", g_sPrefix, "Chat_No_Players_Available");
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandlerMenu_SwitchMusicMVP(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			int target = GetClientOfUserId(StringToInt(info));
			
			if(target)
			{
				if(g_bDisableMVPMusic[param1][target]) // запретить прослушиваение MVP игрока target
				{
					g_bDisableMVPMusic[param1][target] = false; 
					if(strlen(g_sAudioPlayer) != 0 && g_iMVPBuffer == target)
					{
						StopSound(param1, SNDCHAN_AUTO , g_sAudioPlayer);
					}
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Enable_Music_Other_Player", target);
				}
				else
				{
					g_bDisableMVPMusic[param1][target] = true; 
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Disable_Music_Other_Player", target);
				}
				
				Menu_SwitchMusicMVP(param1);
			}
			else
			{
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Client_Left_The_Server");
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Music(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

/* *******************************************************
 *
 *   			        VOLUME
 *
 * ******************************************************** */

public void Menu_Volume(int client)
{
	Menu menu = new Menu(HandlerMenu_Volume);
	char info[128];
	
	FormatEx(info, sizeof(info), "%T \n%T", "Menu_Title_Volume", LANG_SERVER, "Menu_Title_Volume_Stat", LANG_SERVER, g_iVolume[client]);
	menu.SetTitle(info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Increase_50", LANG_SERVER);
	menu.AddItem("+50", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Increase_25", LANG_SERVER);
	menu.AddItem("+25", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Increase_10", LANG_SERVER);
	menu.AddItem("+10", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Increase_5", LANG_SERVER);
	menu.AddItem("+5", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Reduce_50", LANG_SERVER);
	menu.AddItem("-50", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Reduce_25", LANG_SERVER);
	menu.AddItem("-25", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Reduce_10", LANG_SERVER);
	menu.AddItem("-10", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Reduce_5", LANG_SERVER);
	menu.AddItem("-5", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Start_Check_Volume", LANG_SERVER);
	menu.AddItem("start_check", info);
	
	FormatEx(info, sizeof(info), "%T", "Menu_Stop_Check_Volume", LANG_SERVER);
	menu.AddItem("stop_check", info);

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	if(!g_bMenuPosition[client])
	{
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		menu.DisplayAt(client, 6, MENU_TIME_FOREVER);
	}
}

public int HandlerMenu_Volume(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info));
			
			if(StrEqual(info, "+50"))
			{
				if(g_iVolume[param1] + 50 <= 100)
				{
					g_iVolume[param1] += 50;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Increased_Volume", 50, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_100");
				}
				
				g_bMenuPosition[param1] = false;
			}
			else if(StrEqual(info, "+25"))
			{
				if(g_iVolume[param1] + 25 <= 100)
				{
					g_iVolume[param1] += 25;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Increased_Volume", 25, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_100");
				}
				
				g_bMenuPosition[param1] = false;
			}
			else if(StrEqual(info, "+10"))
			{
				if(g_iVolume[param1] + 10 <= 100)
				{
					g_iVolume[param1] += 10;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Increased_Volume", 10, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_100");
				}
				
				g_bMenuPosition[param1] = false;
			}
			else if(StrEqual(info, "+5"))
			{
				if(g_iVolume[param1] + 5 <= 100)
				{
					g_iVolume[param1] += 5;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Increased_Volume", 5, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_100");
				}
				
				g_bMenuPosition[param1] = false;
			}
			else if(StrEqual(info, "-50"))
			{
				if(g_iVolume[param1] - 50 >= 5)
				{
					g_iVolume[param1] -= 50;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Reduced_Volume", 50, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_5");
				}
				
				g_bMenuPosition[param1] = false;
			}
			else if(StrEqual(info, "-25"))
			{
				if(g_iVolume[param1] - 25 >= 5)
				{
					g_iVolume[param1] -= 25;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Reduced_Volume", 25, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_5");
				}
				
				g_bMenuPosition[param1] = false;
			}
			else if(StrEqual(info, "-10"))
			{
				if(g_iVolume[param1] - 10 >= 5)
				{
					g_iVolume[param1] -= 10;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Reduced_Volume", 10, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_5");
				}
				
				g_bMenuPosition[param1] = true;
			}
			else if(StrEqual(info, "-5"))
			{
				if(g_iVolume[param1] - 5 >= 5)
				{
					g_iVolume[param1] -= 5;
					g_flVolume[param1] = float(g_iVolume[param1]) / 100;
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Reduced_Volume", 5, g_iVolume[param1]);
				}
				else
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Cant_Volume_5");
				}
				
				g_bMenuPosition[param1] = true;
			}
			else if(StrEqual(info, "start_check"))
			{
				if(strlen(g_sCheckVolume) > 1) // если уже была запущенная првоерка
					StopSound(param1, SNDCHAN_AUTO, g_sCheckVolume);
				
				if(strlen(g_sAudioPlayer) > 1) 
					StopSound(param1, SNDCHAN_AUTO, g_sAudioPlayer); // если в этот момент играет музыка MVP
					
				if(strlen(g_sPlaylist[param1]) > 1)
					StopSound(param1, SNDCHAN_AUTO, g_sPlaylist[param1]);  // g_sPlaylist - если в вашем плей-листе уже играет музыка
				
				EmitSoundToClient(param1, g_sCheckVolume, -2, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_flVolume[param1]);
				
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Start_Check_Volume");
				
				g_bMenuPosition[param1] = true;
			}
			else if(StrEqual(info, "stop_check"))
			{
				if(strlen(g_sCheckVolume) > 1) 
					StopSound(param1, SNDCHAN_AUTO, g_sCheckVolume);
					
				if(gc_bPluginMessage.BoolValue) CPrintToChat(param1, "%s %t", g_sPrefix, "Chat_Stop_Check_Volume");
				
				g_bMenuPosition[param1] = true;
			}
			
			Menu_Volume(param1);
		}
		case MenuAction_Cancel:
		{
			g_bMenuPosition[param1] = false;
			
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Music(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}