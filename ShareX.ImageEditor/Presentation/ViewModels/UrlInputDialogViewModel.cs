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

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ShareX.ImageEditor.Presentation.ViewModels
{
    public partial class UrlInputDialogViewModel : ObservableObject
    {
        [ObservableProperty]
        private string _url = string.Empty;

        [ObservableProperty]
        private string? _errorMessage;

        [ObservableProperty]
        private bool _isLoading;

        public IRelayCommand OkCommand { get; }
        public IRelayCommand CancelCommand { get; }

        private readonly Action<string> _onOk;
        private readonly Action _onCancel;

        public UrlInputDialogViewModel(Action<string> onOk, Action onCancel, string? initialUrl = null)
        {
            _onOk = onOk;
            _onCancel = onCancel;

            OkCommand = new RelayCommand(Submit, CanSubmit);
            CancelCommand = new RelayCommand(() => _onCancel());

            if (!string.IsNullOrEmpty(initialUrl))
            {
                Url = initialUrl;
            }
        }

        partial void OnUrlChanged(string value)
        {
            ErrorMessage = null;
            OkCommand.NotifyCanExecuteChanged();
        }

        partial void OnIsLoadingChanged(bool value)
        {
            OkCommand.NotifyCanExecuteChanged();
        }

        private bool CanSubmit() => !string.IsNullOrWhiteSpace(Url) && !IsLoading;

        private void Submit()
        {
            ErrorMessage = null;

            string trimmedUrl = Url.Trim();

            if (!Uri.TryCreate(trimmedUrl, UriKind.Absolute, out var uri) ||
                (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
            {
                ErrorMessage = "Please enter a valid HTTP or HTTPS URL.";
                return;
            }

            _onOk(trimmedUrl);
        }
    }
}
