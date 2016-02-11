package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '2'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
      if redis:get("bot:markread") then
        if redis:get("bot:markread") == "on" then
          mark_read(receiver, ok_cb, false)
        end
      end
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "anti_spam",
    "owners",
    "arabic_lock",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban",
    "admin",
    "antilink",
    "linkpv",
    "share",
    "boobs",
    "block",
    "time",
    "location",
    "plugins",
    "google",
    "left",
    "spm",
    "chatbot",
    "version",
    "support",
    "gps",
    "stats",
    "filterword",
    "lock_join"
    },
    sudo_users = {142314165},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[ 
    UB Helper1 	V3 😎👊
    😸An advance Administration bot based on nod32😸
    
 
    Sudo & Manager 👑@CIA_EMC_besick👑 
     
    Our channel : 🔱@UB_CH🔱
    
    http://8pic.ir/images/q7yotypchmj2lqunooku.jpg
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
Create a group

!createrealm [Name]
Create a realm

!setname [Name]
Set realm name

!setabout [GroupID] [Text]
Set a group's about text

!setrules [GroupID] [Text]
Set a group's rules

!lock [GroupID] [setting]
Lock a group's setting

!unlock [GroupID] [setting]
Unock a group's setting

!wholist
Get a list of members in group/realm

!who
Get a file of members in group/realm

!type
Get group type

!kill chat [GroupID]
Kick all memebers and delete group

!kill realm [RealmID]
Kick all members and delete realm

!addadmin [id|username]
Promote an admin by id OR username *Sudo only

!removeadmin [id|username]
Demote an admin by id OR username *Sudo only

!list groups
Get a list of all groups

!list realms
Get a list of all realms

!log
Grt a logfile of current group or realm

!broadcast [text]
!broadcast Hello !
Send text to all groups
Only sudo users can run this command

!bc [group_id] [text]
!bc 123456789 Hello !
This command will send text to [group_id]

]],
    help_text = [[
UB Helper1 Commands list :
 
1-banhammer list
 
!kick [username|id]
(برای حذف کردن شخص از )

!ban [ username|id]
(محروم کردن شخص از گزوه)

!unban [id]
(حذف مسدودیت شخص محروم شده)

!kickme
خارج شدن از گروه مورد نظر

2-Statistics list

!who
مخصات نسبی اشخاص موجود در گروه

!stats
امار کلی گروه

!modlist
فهرست مدیران گروه

!banlist
فهرست افراد محروم شده از گروه

3-Rate Member

!promote [username]
(عطا مدیریت جدید (همراه ریپلی)

!demote [username]
(اخذ مدیریت قدیم (همراه ریپلی)

4-General changes

!setname [name group]
نام گذاری اسم گروه

!setphoto
عکس گذاری برای اواتار گروه

!set rules <text>
قانون گذاری جدید برای گروه

!set about <text>
معرفگذاری برای معرفی گروه

!setflood [value]
تعیین میزان حساسیت ربات به هرزنامه

5-View details

!about
معرفی گروه

!rules
قوانین گروه

!settings
مشاهده تنظیمات کنونی گروه

!help
فهرست کمکی کار با ربات UB Helper1

6-Security Group

!filter + word
محدود کردن اعضا گروه به کلمات ممنوع

!filter - word
از میان برداشتن محدودیت کلمات ممنوع

!lock member 
محدود کردن به اضافه کردن افراد جدید

!lock join
محدود کردن به اضافه شدن اشخاص توسط  link

!lock name
جلوگیری از تعویض اسم گروه

!lock leave
برای محدود شدن اشخاص ترک کننده گروه

!lock english
محدود کردن همه زبان ها به انگلیسی

!lock arabic
محدود کردن همه زبان ها به عربی

!unlock 
[member*name*leave]
[link*tag*arabic*bots]
از میان برداشتن محدودیت ها

7-Fun time 

!time country city
ساعت کشور مورد نظر

!loc country city
مشخصات کشور و شهر مورد نظر

!google
جستجو در www.google.com
 
!gps
 مکان کشور , شهر مورد نظر تحت گوگل

8-Service Provider

!newlink
ایجاد لینک جدید برای پیوستن به گروه

!link
نمایش لینک گروه

!linkpv
فرستادن لینک گروه در گپ خصوصی
(حتما شماره ربات را ذخیره کنید)

9-Member Profile and Group

!owner
مالک گروه

!id
ایدی گروه برای پیوستن

!res [@username]
در اوردن ایدی شخص مورد نظر

!info 
مخشصات فرد مورد نظر

!info 
مشخصات کلی خود

10-bot number & support

!share
دریافت شماره ربات

!support
وصل شدن به پشتیبانی UB /Helper1/Helper2

!version
ورژن ربات

you can use both "/" and "!" 
.شما میتوانید از ! و / استفاده کنید

Developer: @CIA_EMC_besik
توسعه دهنده

channel: @UB_CH
کانال ما
]]
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
