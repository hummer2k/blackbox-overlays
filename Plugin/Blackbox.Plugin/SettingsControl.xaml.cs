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

using SimHub.Plugins.Styles;
using System.Diagnostics;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace Blackbox.Plugin
{
    public class SettingsControlViewModel
    {
        public Blackbox Plugin { get; }

        public SettingsControlViewModel()
        {
        }
        public SettingsControlViewModel(Blackbox plugin) : this()
        {
            Plugin = plugin;
        }
    }

    /// <summary>
    /// Logique d'interaction pour SettingsControl.xaml
    /// </summary>
    public partial class SettingsControl : UserControl
    {
        public Visibility DebugVisibility
        {
            get
            {
#if DEBUG
                return Visibility.Visible;
#else
                return Visibility.Collapsed;
#endif
            }
        }

        public Blackbox Plugin { get; }

        public SettingsControl()
        {
            InitializeComponent();
        }

        public SettingsControl(Blackbox plugin) : this()
        {
            this.Plugin = plugin;
            this.DataContext = new SettingsControlViewModel(plugin);
        }

        private static void OpenUrl(string url)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true // Ensures it opens in the default browser
            });
        }

        private void GitHubLink_Click(object sender, RoutedEventArgs e)
        {
            OpenUrl(VersionChecker.ProjectUrl);
        }

        private void UpstreamLink_Click(object sender, RoutedEventArgs e)
        {
            OpenUrl("https://github.com/fixfactory/bo2-official-overlays");
        }

        private void CheckForUpdates_Click(object sender, RoutedEventArgs e)
        {
            if (CheckForUpdates.IsChecked == true)
            {
                Task.Run(() =>
                {
                    VersionChecker versionChecker = new VersionChecker();
                    versionChecker.CheckForUpdateAsync().Wait();
                });
            }
        }
    }
}