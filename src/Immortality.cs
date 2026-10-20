using HarmonyLib;
using Godot;
using System;
using System.IO;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Modding;
using MegaCrit.Sts2.Core.Nodes;

[ModInitializer("Initialize")]
public static class StayAlive
{
    public static bool Enabled { get; private set; } = true;
    private static Button toggleButton;
    private static readonly string ConfigPath = Path.Combine(
        System.Environment.GetFolderPath(System.Environment.SpecialFolder.ApplicationData),
        "SlayTheSpire2", "StayAlive.enabled");

    public static void Initialize()
    {
        try
        {
            if (File.Exists(ConfigPath) && bool.TryParse(File.ReadAllText(ConfigPath), out bool saved))
                Enabled = saved;
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        new Harmony("local.StayAlive").PatchAll();
    }

    public static void Toggle()
    {
        Enabled = !Enabled;
        Refresh();
        try { File.WriteAllText(ConfigPath, Enabled.ToString()); }
        catch (IOException) { GD.PushWarning("StayAlive: could not save switch setting."); }
        catch (UnauthorizedAccessException) { GD.PushWarning("StayAlive: could not save switch setting."); }
    }

    public static void AddSwitch(NGame game)
    {
        if (GodotObject.IsInstanceValid(toggleButton)) return;
        var layer = new CanvasLayer { Layer = 100 };
        game.AddChild(layer);
        var root = new Control { MouseFilter = Control.MouseFilterEnum.Ignore };
        layer.AddChild(root);
        root.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        toggleButton = new Button
        {
            FocusMode = Control.FocusModeEnum.None,
            TooltipText = "点击或按 F8 切换。开启时玩家生命最低为1；关闭后正常扣血。"
        };
        root.AddChild(toggleButton);
        toggleButton.AnchorLeft = 1;
        toggleButton.AnchorRight = 1;
        toggleButton.OffsetLeft = -230;
        toggleButton.OffsetRight = -20;
        toggleButton.OffsetTop = 80;
        toggleButton.OffsetBottom = 124;
        toggleButton.Pressed += Toggle;
        Refresh();
    }

    private static void Refresh()
    {
        if (GodotObject.IsInstanceValid(toggleButton))
            toggleButton.Text = Enabled ? "不死：开启 [F8]" : "不死：关闭 [F8]";
    }
}

[HarmonyPatch(typeof(NGame), "_Ready")]
public static class SwitchUi
{
    public static void Postfix(NGame __instance) => StayAlive.AddSwitch(__instance);
}

[HarmonyPatch(typeof(NGame), "_Input")]
public static class SwitchHotkey
{
    public static void Postfix(NGame __instance, InputEvent inputEvent)
    {
        StayAlive.AddSwitch(__instance);
        if (inputEvent is InputEventKey key && key.Pressed && !key.Echo && key.Keycode == Key.F8)
            StayAlive.Toggle();
    }
}

[HarmonyPatch(typeof(Creature), "set_CurrentHp")]
public static class MinimumHealth
{
    public static void Prefix(Creature __instance, ref int value)
    {
        if (StayAlive.Enabled && __instance.IsPlayer && value <= 0) value = 1;
    }
}
