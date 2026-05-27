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

using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using ShareX.ImageEditor.Presentation.Theming;
using System.Threading;

namespace ShareX.ImageEditor.Presentation.ViewModels
{
    public partial class MainViewModel : ViewModelBase
    {
        private static readonly TimeSpan DefaultNotificationDuration = TimeSpan.FromSeconds(2.4);
        private static readonly TimeSpan NotificationHideDuration = TimeSpan.FromMilliseconds(220);

        private int _notificationVersion;

        [ObservableProperty]
        private bool _isNotificationVisible;

        [ObservableProperty]
        private bool _isNotificationOpen;

        [ObservableProperty]
        private string _notificationMessage = string.Empty;

        [ObservableProperty]
        private string _notificationIcon = string.Empty;

        public bool HasNotificationIcon => !string.IsNullOrWhiteSpace(NotificationIcon);

        partial void OnNotificationIconChanged(string value)
        {
            OnPropertyChanged(nameof(HasNotificationIcon));
        }

        public void ShowNotification(string message, string? icon = null, TimeSpan? duration = null)
        {
            if (!Options.ShowNotifications || string.IsNullOrWhiteSpace(message))
            {
                return;
            }

            _ = ShowNotificationAsync(message, icon, duration ?? DefaultNotificationDuration);
        }

        private void HideNotification()
        {
            Interlocked.Increment(ref _notificationVersion);
            NotificationMessage = string.Empty;
            NotificationIcon = string.Empty;
            IsNotificationOpen = false;
            IsNotificationVisible = false;
        }

        public void DismissNotification()
        {
            HideNotification();
        }

        private void ShowTaskActionNotification(string message, string icon)
        {
            if (Options.AutoCloseEditorOnTask)
            {
                return;
            }

            ShowNotification(message, icon);
        }

        public void ShowOpenImageNotification(string? filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
            {
                return;
            }

            ShowNotification(BuildFilePathNotification("Image opened.", filePath), EditorIcons.FileOpen);
        }

        public void ShowImageCroppedNotification()
        {
            ShowNotification("Image cropped.", EditorIcons.ToolCrop);
        }

        public void ShowImageCutOutNotification()
        {
            ShowNotification("Image cut out.", EditorIcons.ToolCutOut);
        }

        private void ShowSaveNotification(string? savedPath, string icon)
        {
            if (string.IsNullOrWhiteSpace(savedPath))
            {
                return;
            }

            ShowTaskActionNotification(BuildFilePathNotification("Image saved to file.", savedPath), icon);
        }

        private static string BuildFilePathNotification(string headline, string filePath)
        {
            return $"{headline}\nFile path: {filePath}";
        }

        private static async Task InvokeRequestedHandlersAsync(Func<Task>? handlers)
        {
            if (handlers == null)
            {
                return;
            }

            Delegate[] invocationList = handlers.GetInvocationList();

            for (int i = 0; i < invocationList.Length; i++)
            {
                Func<Task> handler = (Func<Task>)invocationList[i];
                await handler();
            }
        }

        private static async Task<string?> InvokeRequestedHandlersAsync(Func<Task<string?>>? handlers)
        {
            if (handlers == null)
            {
                return null;
            }

            string? result = null;
            Delegate[] invocationList = handlers.GetInvocationList();

            for (int i = 0; i < invocationList.Length; i++)
            {
                Func<Task<string?>> handler = (Func<Task<string?>>)invocationList[i];
                string? currentResult = await handler();

                if (!string.IsNullOrWhiteSpace(currentResult))
                {
                    result = currentResult;
                }
            }

            return result;
        }

        private async Task ShowNotificationAsync(string message, string? icon, TimeSpan duration)
        {
            int notificationVersion = Interlocked.Increment(ref _notificationVersion);

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                NotificationMessage = message;
                NotificationIcon = icon ?? string.Empty;
                IsNotificationVisible = true;
                IsNotificationOpen = true;
            });

            await Task.Delay(duration);

            if (notificationVersion != Volatile.Read(ref _notificationVersion))
            {
                return;
            }

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                if (notificationVersion == Volatile.Read(ref _notificationVersion))
                {
                    IsNotificationOpen = false;
                }
            });

            await Task.Delay(NotificationHideDuration);

            if (notificationVersion != Volatile.Read(ref _notificationVersion))
            {
                return;
            }

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                if (notificationVersion == Volatile.Read(ref _notificationVersion))
                {
                    NotificationMessage = string.Empty;
                    NotificationIcon = string.Empty;
                    IsNotificationVisible = false;
                }
            });
        }
    }
}