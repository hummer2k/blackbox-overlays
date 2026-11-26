/*
    benofficial2's Official Overlays
    Copyright (C) 2025-2026 benofficial2

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

using GameReaderCommon;
using SimHub.Plugins;
using System.ComponentModel;

namespace Blackbox.Plugin
{
    public class TrackWetnessSettings : ModuleSettings
    {
        public bool HideInReplay { get; set; } = true;
        public bool HideWhenZero { get; set; } = true;

        public int BackgroundOpacity { get; set; } = 0;
    }

    public class TrackWetnessModule : PluginModuleBase
    {
        public TrackWetnessSettings Settings { get; set; }

        public override void Init(PluginManager pluginManager, Blackbox plugin)
        {
            Settings = plugin.ReadCommonSettings<TrackWetnessSettings>("TrackWetnessSettings", () => new TrackWetnessSettings());
            plugin.AttachDelegate(name: "TrackWetness.HideInReplay", valueProvider: () => Settings.HideInReplay);
            plugin.AttachDelegate(name: "TrackWetness.HideWhenZero", valueProvider: () => Settings.HideWhenZero);
            plugin.AttachDelegate(name: "TrackWetness.BackgroundOpacity", valueProvider: () => Settings.BackgroundOpacity);
        }

        public override void DataUpdate(PluginManager pluginManager, Blackbox plugin, ref GameData data)
        {

        }

        public override void End(PluginManager pluginManager, Blackbox plugin)
        {
            plugin.SaveCommonSettings("TrackWetnessSettings", Settings);
        }
    }
}
