-- Client bootstrap: one ScreenGui, responsive scale, controllers wired together.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = script.Parent.UI
local Kit = require(UI.Kit)
local ClientState = require(script.Parent.ClientState)
local Controllers = script.Parent.Controllers
local HUD = require(Controllers.HUD)
local Notifications = require(Controllers.Notifications)
local Effects = require(Controllers.Effects)
local TrainingUI = require(Controllers.TrainingUI)
local BenchAnimator = require(Controllers.BenchAnimator)
local VaultBeacon = require(Controllers.VaultBeacon)
local Ambience = require(Controllers.Ambience)
local GameFeel = require(Controllers.GameFeel)
local MenuController = require(script.Parent.Menus.MenuController)

local player = Players.LocalPlayer

local gui = Kit.new("ScreenGui", {
	Name = "SAT_HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Responsive scale: designed at 1280x720; phones shrink, TVs grow.
local scale = Kit.new("UIScale", { Parent = gui })
local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.5, 1.15)
	if GuiService:IsTenFootInterface() then
		s *= 1.2
	end
	scale.Scale = s
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

ClientState.Init()
HUD.Init(gui)
Notifications.Init(gui, HUD.TopStack)
Effects.Init()
TrainingUI.Init(gui)
BenchAnimator.Init()
VaultBeacon.Init()
Ambience.Init()
GameFeel.Init()
MenuController.Init(gui)
HUD.OpenMenu = MenuController.Open

-- Ask the server for our snapshot now that every listener is connected.
Net.Get("ClientReady"):FireServer()
