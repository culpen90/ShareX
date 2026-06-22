#region License Information (GPL v3)

/*
    ShareX - A program that allows you to take screenshots and share any file type
    Copyright (c) 2007-2026 ShareX Team

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

    Optionally you can also view the license at <http://www.gnu.org/licenses/>.
*/

#endregion License Information (GPL v3)

using Avalonia.Input;
using CommunityToolkit.Mvvm.Input;
using System.Collections.ObjectModel;

namespace ShareX.ImageEditor.Presentation.ViewModels
{
    public partial class MainViewModel : ViewModelBase
    {
        private readonly ObservableCollection<ToolbarCustomizationItemViewModel> _toolbarItems = new();

        public ReadOnlyObservableCollection<ToolbarCustomizationItemViewModel> ToolbarItems { get; private set; } = null!;

        private void InitializeToolbarCustomization()
        {
            ToolbarItems = new ReadOnlyObservableCollection<ToolbarCustomizationItemViewModel>(_toolbarItems);
            ApplyToolbarCustomizationItems(
                ToolbarCustomizationItemViewModel.CreateFromOptions(Options.ToolbarItems),
                persist: Options.ToolbarItems.Count == 0);
        }

        [RelayCommand]
        private void OpenToolbarCustomizationDialog()
        {
            if (IsModalOpen)
            {
                return;
            }

            var dialog = new ToolbarCustomizationDialogViewModel(
                _toolbarItems,
                items =>
                {
                    ApplyToolbarCustomizationItems(items, persist: true);
                    CloseModalCommand.Execute(null);
                },
                () => CloseModalCommand.Execute(null));

            ModalContent = dialog;
            IsModalOpen = true;
        }

        internal bool TrySelectToolForToolbarHotkey(Key key, KeyModifiers modifiers)
        {
            foreach (ToolbarCustomizationItemViewModel item in _toolbarItems)
            {
                if (ToolbarHotkeyHelper.Matches(item.Hotkey, key, modifiers))
                {
                    SelectToolCommand.Execute(item.Tool);
                    return true;
                }
            }

            return false;
        }

        private void ApplyToolbarCustomizationItems(IEnumerable<ToolbarCustomizationItemViewModel> items, bool persist)
        {
            _toolbarItems.Clear();

            foreach (ToolbarCustomizationItemViewModel item in items.Select(item => item.Clone()))
            {
                _toolbarItems.Add(item);
            }

            UpdateToolbarActiveStates();
            OnPropertyChanged(nameof(ToolbarItems));

            if (persist)
            {
                Options.ToolbarItems = _toolbarItems.Select(item => item.ToOptions()).ToList();
            }
        }

        private void UpdateToolbarActiveStates()
        {
            foreach (ToolbarCustomizationItemViewModel item in _toolbarItems)
            {
                item.IsActive = item.Tool == ActiveTool;
            }
        }
    }
}
