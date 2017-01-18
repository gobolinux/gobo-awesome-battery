
local battery = {}

local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local lfs = require("lfs")
local timer = gears.timer or timer

local lgi = require("lgi")
local cairo = lgi.require("cairo")

local function draw_glow(cr, x, y, w, h, r, g, b, a, rad)
   local glow = cairo.Pattern.create_mesh()
   local function set_colors()
      glow:set_corner_color_rgba(0, r, g, b, a)
      glow:set_corner_color_rgba(1, r, g, b, 0)
      glow:set_corner_color_rgba(2, r, g, b, 0)
      glow:set_corner_color_rgba(3, r, g, b, a)
   end
   local function draw_side(x1, y1, x2, y2, x3, y3, x4, y4)
      glow:begin_patch()
      glow:move_to(x1, y1)
      glow:line_to(x2, y2)
      glow:line_to(x3, y3)
      glow:line_to(x4, y4)
      glow:line_to(x1, y1)
      set_colors()
      glow:end_patch()
   end
   draw_side(x, y, x-rad, y-rad, x-rad, y+h+rad, x, y+h) -- left
   draw_side(x, y, x-rad, y-rad, x+w+rad, y-rad, x+w, y) -- top
   draw_side(x+w, y, x+w+rad, y-rad, x+w+rad, y+h+rad, x+w, y+h) -- right
   draw_side(x+w, y+h, x+w+rad, y+h+rad, x-rad, y+h+rad, x, y+h) -- bottom
   cr:set_source(glow)
   cr:paint()
end

local function glow_rectangle(cr, x, y, w, h, r, g, b, a, rad)
   draw_glow(cr, x, y, w, h, r, g, b, a, rad)
   cr:set_source_rgb(r, g, b)
   cr:rectangle(x, y, w, h)
   cr:fill()
end

local function draw_icon(surface, state)
   local cr = cairo.Context(surface)
  
   cr:set_source_rgb(0.5, 0.5, 0.5)
   cr:rectangle(25, 20, 50, 70)
   cr:rectangle(35, 10, 30, 10)
   cr:fill()

   local height = 80 * (state.percent / 100)

   if state.percent < 15 then
      glow_rectangle(cr, 25, 90 - height, 50, height, 1, 0, 0, 0.4, 8)
   else
      if height > 70 then
         local topheight = height - 70
         glow_rectangle(cr, 35, 20 - topheight, 30, topheight, 0, 1, 0.75, 0.3, 8)
         height = 70
      end
      glow_rectangle(cr, 25, 90 - height, 50, height, 0, 1, 0.75, 0.3, 8)
   end
   
   if state.mode == "Charging" then
      cr:set_source_rgb(0, 0, 0)
      cr:move_to(35, 80)
      cr:line_to(45, 55)
      cr:line_to(35, 55)
      cr:line_to(45, 30)
      cr:line_to(65, 30)
      cr:line_to(55, 45)
      cr:line_to(65, 45)
      cr:line_to(35, 80)
      cr:fill()
   end
end

local function notify_battery_level(state, image, timeout)
   if not image then
      image = cairo.ImageSurface("ARGB32", 100, 100)
      draw_icon(image, state)
   end
   local mode
   if state.mode == "Charging"
   then
      mode = "<b>Charging</b><br/>"
   elseif state.percent <= 15 then
      mode = "<b>Warning</b><br/>"
   else
      mode = ""
   end
   local text = mode .. "Battery level at <b>"..state.percent.."%</b>"
   local icon = cairo.ImageSurface("ARGB32", 70, 100)
   local cr = cairo.Context(icon)
   cr:set_source_surface(image, -15, 0)
   cr:paint()
   naughty.notify { icon = icon, text = text, timeout = timeout or 2 }
end

local function update_icon(widget, state)
   local image = cairo.ImageSurface("ARGB32", 100, 100)
   draw_icon(image, state)
   widget:set_image(image)
   if state.alert then
      notify_battery_level(state, image, 5)
      state.alert = false
   end
end

local function update(state)
   local basedir = "/sys/class/power_supply"
   local old_percent = state.percent
   local dir_iter, dir_obj = lfs.dir(basedir)
   for dir in dir_iter, dir_obj do
      local fd = io.open(basedir.."/"..dir.."/capacity", "r")
      if fd then
         local capacity = tonumber(fd:read("*a"))
         fd:close()
         if capacity then
            state.percent = capacity
         end
         fd = io.open(basedir.."/"..dir.."/status", "r")
         if fd then
            state.mode = fd:read("*l")
            fd:close()
         end
         dir_obj:close()
         break
      end
   end
   if state.mode ~= "Charging" and 
      ((old_percent > 15 and state.percent <= 15) or
       (old_percent > 10 and state.percent <= 10) or
       (old_percent > 5 and state.percent <= 5) or
       (old_percent > 1 and state.percent <= 1))
   then
      state.alert = true
   end
end

function battery.new()
   local widget = wibox.widget.imagebox()
   local state = {
      percent = 100
   }
   update(state)
   if not state.mode then
      -- Return empty widget. No battery detected.
      return widget
   end
   update_icon(widget, state)

   local widget_timer = timer({timeout=5})
   widget_timer:connect_signal("timeout", function()
      update(state)
      update_icon(widget, state)
   end)
   widget_timer:start()

   local last_notification = 0
   local notify_status = function()
      local now = os.time()
      if last_notification < now - 2 then
         notify_battery_level(state)
         last_notification = now
      end
   end

   widget:buttons(
      awful.util.table.join(
         awful.button({ }, 1, notify_status),
         awful.button({ }, 3, notify_status)
      )
   )

   return widget
end

return battery
