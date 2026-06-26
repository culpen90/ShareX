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

using Avalonia.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using ShareX.ImageEditor.Core.BackgroundRemoval;
using ShareX.ImageEditor.Hosting;
using ShareX.ImageEditor.Presentation.Rendering;
using SkiaSharp;
using System.Collections.ObjectModel;

namespace ShareX.ImageEditor.Presentation.ViewModels;

public sealed partial class BackgroundRemoverViewModel : ViewModelBase, IDisposable
{
    private readonly BackgroundRemovalService _backgroundRemovalService = new();
    private SKBitmap? _sourceBitmap;

    public BackgroundRemoverViewModel(string? modelsFolder)
    {
        ModelsFolder = modelsFolder;
        RefreshModels();
    }

    public ObservableCollection<BackgroundRemovalModel> AvailableModels { get; } = [];

    public string? ModelsFolder { get; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasSelectedModel))]
    [NotifyPropertyChangedFor(nameof(CanRemoveBackground))]
    [NotifyCanExecuteChangedFor(nameof(RemoveBackgroundCommand))]
    private BackgroundRemovalModel? _selectedModel;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasImage))]
    [NotifyPropertyChangedFor(nameof(CanRemoveBackground))]
    [NotifyCanExecuteChangedFor(nameof(RemoveBackgroundCommand))]
    private string? _imagePath;

    [ObservableProperty]
    private Bitmap? _previewImage;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CanRemoveBackground))]
    [NotifyCanExecuteChangedFor(nameof(BrowseImageCommand))]
    [NotifyCanExecuteChangedFor(nameof(RefreshModelsCommand))]
    [NotifyCanExecuteChangedFor(nameof(RemoveBackgroundCommand))]
    private bool _isProcessing;

    public Func<string, Task<string?>>? SelectImageFileRequested { get; set; }

    public bool HasImage => !string.IsNullOrEmpty(ImagePath);

    public bool HasSelectedModel => SelectedModel != null;

    public bool CanRemoveBackground => HasImage && HasSelectedModel && !IsProcessing;

    [RelayCommand(CanExecute = nameof(CanRefreshModels))]
    private void RefreshModels()
    {
        AvailableModels.Clear();
        SelectedModel = null;

        if (string.IsNullOrWhiteSpace(ModelsFolder))
        {
            return;
        }

        try
        {
            Directory.CreateDirectory(ModelsFolder);

            foreach (string modelPath in Directory.EnumerateFiles(ModelsFolder, "*.onnx", SearchOption.TopDirectoryOnly).OrderBy(Path.GetFileName))
            {
                FileInfo fileInfo = new(modelPath);
                AvailableModels.Add(new BackgroundRemovalModel
                {
                    FilePath = fileInfo.FullName,
                    FileName = fileInfo.Name,
                    FileSize = fileInfo.Length
                });
            }

            SelectedModel = AvailableModels.FirstOrDefault();
        }
        catch (Exception ex)
        {
            EditorServices.ReportWarning(nameof(BackgroundRemoverViewModel), "Failed to scan background removal models.", ex);
        }
    }

    [RelayCommand(CanExecute = nameof(CanBrowseImage))]
    private async Task BrowseImageAsync()
    {
        if (SelectImageFileRequested == null)
        {
            return;
        }

        string? filePath = await SelectImageFileRequested("Select image");
        if (string.IsNullOrEmpty(filePath))
        {
            return;
        }

        try
        {
            SKBitmap? bitmap = SKBitmap.Decode(filePath);
            if (bitmap == null)
            {
                return;
            }

            SetSourceImage(bitmap, filePath);
        }
        catch (Exception ex)
        {
            EditorServices.ReportWarning(nameof(BackgroundRemoverViewModel), $"Failed to load image '{filePath}'.", ex);
        }
    }

    [RelayCommand(CanExecute = nameof(CanRemoveBackground))]
    private async Task RemoveBackgroundAsync()
    {
        if (_sourceBitmap == null)
        {
            return;
        }

        if (SelectedModel == null)
        {
            return;
        }

        try
        {
            IsProcessing = true;
            BackgroundRemovalModel selectedModel = SelectedModel!;

            SKBitmap sourceCopy = _sourceBitmap.Copy();
            SKBitmap result = await Task.Run(() =>
            {
                using (sourceCopy)
                {
                    return _backgroundRemovalService.RemoveBackground(sourceCopy, selectedModel);
                }
            });

            SetSourceImage(result, ImagePath);
        }
        catch (Exception ex)
        {
            EditorServices.ReportWarning(nameof(BackgroundRemoverViewModel), "Background removal failed.", ex);
        }
        finally
        {
            IsProcessing = false;
        }
    }

    private bool CanBrowseImage()
    {
        return !IsProcessing;
    }

    private bool CanRefreshModels()
    {
        return !IsProcessing;
    }

    private void SetSourceImage(SKBitmap bitmap, string? filePath)
    {
        Bitmap preview = BitmapConversionHelpers.ToAvaloniBitmap(bitmap);

        _sourceBitmap?.Dispose();
        PreviewImage?.Dispose();

        _sourceBitmap = bitmap;
        PreviewImage = preview;
        ImagePath = filePath;
    }

    public void Dispose()
    {
        _sourceBitmap?.Dispose();
        PreviewImage?.Dispose();
    }
}
