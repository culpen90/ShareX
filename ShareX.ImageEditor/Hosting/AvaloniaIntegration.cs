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

using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Themes.Fluent;
using Avalonia.Threading;
using ShareX.ImageEditor.Hosting.Diagnostics;
using ShareX.ImageEditor.Presentation.ViewModels;
using ShareX.ImageEditor.Presentation.Views;
using SkiaSharp;
using System.Threading;

namespace ShareX.ImageEditor.Hosting
{
    public class AvaloniaApp : Application
    {
        public override void Initialize()
        {
            Styles.Add(new FluentTheme());
        }

        public override void OnFrameworkInitializationCompleted()
        {
            if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            {
                // No main window here, we manage windows manually
                desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;
            }

            base.OnFrameworkInitializationCompleted();
        }
    }

    public class EditorEvents
    {
        public Action<SKBitmap>? CopyImageRequested { get; set; }
        public Func<SKBitmap, string?, string?>? SaveImageRequested { get; set; }
        public Func<SKBitmap, string?, string?>? SaveImageAsRequested { get; set; }
        public Action<SKBitmap>? PrintImageRequested { get; set; }
        public Action<SKBitmap>? PinImageRequested { get; set; }
        public Action<SKBitmap>? UploadImageRequested { get; set; }
        public Action<EditorDiagnosticEvent>? DiagnosticReported { get; set; }
        public string? ImageFilePath { get; set; }
    }

    public static class AvaloniaIntegration
    {
        private static bool initialized = false;
        private static readonly object _initLock = new object();
        private static Thread? _uiThread;
        private static ManualResetEventSlim? _uiThreadReady;
        private static Dispatcher? _uiDispatcher;
        private static Exception? _uiThreadInitializationException;

        public static void Initialize()
        {
            if (!initialized)
            {
                lock (_initLock)
                {
                    if (!initialized)
                    {
                        EnsureUiThread();
                        initialized = true;
                    }
                }
            }
        }

        private static void EnsureUiThread()
        {
            if (_uiThread != null && _uiDispatcher != null)
            {
                return;
            }

            _uiThreadReady = new ManualResetEventSlim(false);
            _uiThreadInitializationException = null;
            _uiThread = new Thread(() =>
            {
                try
                {
                    EditorServices.EnsureDefaultDesktopWallpaperService();

                    if (Application.Current == null)
                    {
                        AppBuilder builder = AppBuilder.Configure<AvaloniaApp>()
                            .UsePlatformDetect()
                            .WithInterFont();

#if DEBUG
                        builder = builder.LogToTrace();
#endif

                        builder.SetupWithoutStarting();
                    }

                    _uiDispatcher = Dispatcher.UIThread;
                    _uiThreadReady?.Set();
                    Dispatcher.UIThread.MainLoop(CancellationToken.None);
                }
                catch (Exception ex)
                {
                    _uiThreadInitializationException = ex;
                    _uiThreadReady?.Set();
                }
            })
            {
                IsBackground = true,
                Name = nameof(AvaloniaIntegration) + "UIThread"
            };

            if (OperatingSystem.IsWindows())
            {
                _uiThread.SetApartmentState(ApartmentState.STA);
            }

            _uiThread.Start();
            _uiThreadReady.Wait();

            if (_uiDispatcher == null)
            {
                throw new InvalidOperationException("Failed to initialize Avalonia UI thread.", _uiThreadInitializationException);
            }
        }

        private static void InvokeOnUiThread(Action action)
        {
            InvokeOnUiThread<object?>(() =>
            {
                action();
                return null;
            });
        }

        private static T InvokeOnUiThread<T>(Func<T> action)
        {
            Initialize();

            if (_uiDispatcher == null)
            {
                throw new InvalidOperationException("Avalonia UI dispatcher is not available.");
            }

            if (_uiDispatcher.CheckAccess())
            {
                return action();
            }

            using ManualResetEventSlim completion = new ManualResetEventSlim(false);
            T result = default!;
            Exception? exception = null;

            _uiDispatcher.Post(() =>
            {
                try
                {
                    result = action();
                }
                catch (Exception ex)
                {
                    exception = ex;
                }
                finally
                {
                    completion.Set();
                }
            });

            completion.Wait();

            if (exception != null)
            {
                throw new AggregateException("Avalonia UI operation failed.", exception);
            }

            return result;
        }

        public static void ShowEditor(string filePath)
        {
            InvokeOnUiThread(() =>
            {
                EditorWindow window = new EditorWindow();

                if (!string.IsNullOrEmpty(filePath) && File.Exists(filePath))
                {
                    window.LoadImage(filePath);
                }

                window.Show();
            });
        }

        public static void ShowEditor(Stream imageStream)
        {
            InvokeOnUiThread(() =>
            {
                EditorWindow window = new EditorWindow();

                if (imageStream != null)
                {
                    window.LoadImage(imageStream);
                }

                window.Show();
            });
        }

        public static byte[]? ShowEditorDialog(ImageEditorOptions options, EditorEvents? events = null,
            bool taskMode = false, string? imageFilePath = null)
        {
            return ShowEditorDialog((Stream?)null, options, events, taskMode, imageFilePath);
        }

        public static byte[]? ShowEditorDialog(Stream? imageStream, ImageEditorOptions options, EditorEvents? events = null,
            bool taskMode = false, string? imageFilePath = null)
        {
            if (_uiDispatcher?.CheckAccess() == true)
            {
                throw new InvalidOperationException("Synchronous editor dialogs are not supported on the Avalonia UI thread.");
            }

            Task<byte[]?> dialogTask = InvokeOnUiThread(() =>
                ShowEditorDialogCoreAsync(
                    options,
                    window =>
                    {
                        if (imageStream != null)
                        {
                            window.LoadImage(imageStream);
                        }
                    },
                    events,
                    taskMode,
                    imageFilePath,
                    (window, vm) => vm.TaskResult switch
                    {
                        MainViewModel.EditorTaskResult.Continue => window.GetResultBytes(),
                        MainViewModel.EditorTaskResult.ContinueNoSave => window.GetSourceBytes(),
                        _ => null
                    }));

            return dialogTask.GetAwaiter().GetResult();
        }

        public static SKBitmap? ShowEditorDialogBitmap(ImageEditorOptions options, EditorEvents? events = null,
            bool taskMode = false, string? imageFilePath = null)
        {
            return ShowEditorDialogBitmap((SKBitmap?)null, options, events, taskMode, imageFilePath);
        }

        public static SKBitmap? ShowEditorDialogBitmap(SKBitmap? imageBitmap, ImageEditorOptions options, EditorEvents? events = null,
            bool taskMode = false, string? imageFilePath = null)
        {
            if (_uiDispatcher?.CheckAccess() == true)
            {
                throw new InvalidOperationException("Synchronous editor dialogs are not supported on the Avalonia UI thread.");
            }

            Task<SKBitmap?> dialogTask = InvokeOnUiThread(() =>
                ShowEditorDialogCoreAsync(
                    options,
                    window =>
                    {
                        if (imageBitmap != null)
                        {
                            window.LoadImage(imageBitmap);
                        }
                    },
                    events,
                    taskMode,
                    imageFilePath,
                    (window, vm) => vm.TaskResult switch
                    {
                        MainViewModel.EditorTaskResult.Continue => window.GetResultBitmap(),
                        MainViewModel.EditorTaskResult.ContinueNoSave => window.GetSourceBitmap(),
                        _ => null
                    }));

            return dialogTask.GetAwaiter().GetResult();
        }

        private static Task<T?> ShowEditorDialogCoreAsync<T>(ImageEditorOptions options, Action<EditorWindow>? initializeImage,
            EditorEvents? events, bool taskMode, string? imageFilePath, Func<EditorWindow, MainViewModel, T?> getResult)
            where T : class
        {
            T? result = null;
            IEditorDiagnosticsSink? previousDiagnosticsSink = null;
            bool restoreScopedDiagnostics = false;
            TaskCompletionSource<T?> completion = new TaskCompletionSource<T?>(TaskCreationOptions.RunContinuationsAsynchronously);

            try
            {
                if (events?.DiagnosticReported != null)
                {
                    var diagnosticHandler = events.DiagnosticReported;
                    previousDiagnosticsSink = EditorServices.Diagnostics;
                    restoreScopedDiagnostics = true;

                    EditorServices.Diagnostics = new DelegateEditorDiagnosticsSink(diagnosticEvent =>
                    {
                        try
                        {
                            diagnosticHandler(diagnosticEvent);
                        }
                        catch
                        {
                            // Host diagnostics callback failures must not break the editor.
                        }

                        if (previousDiagnosticsSink != null)
                        {
                            try
                            {
                                previousDiagnosticsSink.Report(diagnosticEvent);
                            }
                            catch
                            {
                                // Ignore downstream sink failures.
                            }
                        }
                    });
                }

                EditorWindow window = new EditorWindow(options);

                initializeImage?.Invoke(window);

                string? filePath = imageFilePath ?? events?.ImageFilePath;

                if (window.DataContext is MainViewModel vm)
                {
                    if (!string.IsNullOrEmpty(filePath))
                    {
                        vm.ImageFilePath = filePath;
                    }

                    vm.ShowFileMenu = true;
                    vm.ShowOptionsButton = true;
                    vm.ShowTaskButtons = true;
                    vm.UseContinueWorkflow = taskMode;
                    vm.ShowBottomToolbar = true;
                    vm.ShowStartScreen = !taskMode;
                }

                SetupEvents(window, events, () =>
                {
                    if (window.DataContext is MainViewModel vm)
                    {
                        result = getResult(window, vm);
                    }
                });

                window.Closed += (s, e) =>
                {
                    if (restoreScopedDiagnostics)
                    {
                        EditorServices.Diagnostics = previousDiagnosticsSink;
                    }

                    completion.TrySetResult(result);
                };

                window.Show();
            }
            catch (Exception ex)
            {
                if (restoreScopedDiagnostics)
                {
                    EditorServices.Diagnostics = previousDiagnosticsSink;
                }

                completion.TrySetException(ex);
            }

            return completion.Task;
        }

        private static void SetupEvents(EditorWindow window, EditorEvents? events, Action onResult)
        {
            if (events == null) return;

            MainViewModel? vm = window.DataContext as MainViewModel;
            if (vm == null) return;

            if (events.CopyImageRequested != null)
            {
                vm.HasHostCopyHandler = true;
                vm.CopyRequested += () =>
                {
                    using var skBitmap = window.GetResultBitmap();
                    if (skBitmap != null)
                    {
                        InvokeHostCallback(skBitmap, events.CopyImageRequested, nameof(EditorEvents.CopyImageRequested));
                    }

                    return Task.CompletedTask;
                };
            }

            if (events.SaveImageRequested != null)
            {
                vm.HasHostSaveHandler = true;
                vm.SaveRequested += () =>
                {
                    string? savedPath = null;

                    using var skBitmap = window.GetResultBitmap();
                    if (skBitmap != null)
                    {
                        savedPath = InvokeHostSaveCallback(skBitmap, vm.ImageFilePath, events.SaveImageRequested, nameof(EditorEvents.SaveImageRequested));
                        if (!string.IsNullOrEmpty(savedPath))
                        {
                            vm.ImageFilePath = savedPath;
                            vm.IsDirty = false;
                        }
                    }

                    return Task.FromResult(savedPath);
                };
            }

            if (events.SaveImageAsRequested != null)
            {
                vm.HasHostSaveAsHandler = true;
                vm.SaveAsRequested += () =>
                {
                    string? savedPath = null;

                    using var skBitmap = window.GetResultBitmap();
                    if (skBitmap != null)
                    {
                        savedPath = InvokeHostSaveCallback(skBitmap, vm.ImageFilePath, events.SaveImageAsRequested, nameof(EditorEvents.SaveImageAsRequested));
                        if (!string.IsNullOrEmpty(savedPath))
                        {
                            vm.ImageFilePath = savedPath;
                            vm.IsDirty = false;
                        }
                    }

                    return Task.FromResult(savedPath);
                };
            }

            if (events.PrintImageRequested != null)
            {
                vm.PrintRequested += () =>
                {
                    using var skBitmap = window.GetResultBitmap();
                    if (skBitmap != null)
                    {
                        InvokeHostCallback(skBitmap, events.PrintImageRequested, nameof(EditorEvents.PrintImageRequested));
                    }
                };
            }

            if (events.PinImageRequested != null)
            {
                vm.PinRequested += () =>
                {
                    using var skBitmap = window.GetResultBitmap();
                    if (skBitmap != null)
                    {
                        InvokeHostCallback(skBitmap, events.PinImageRequested, nameof(EditorEvents.PinImageRequested));
                    }
                };
            }

            if (events.UploadImageRequested != null)
            {
                vm.UploadRequested += () =>
                {
                    using var skBitmap = window.GetResultBitmap();
                    if (skBitmap != null)
                    {
                        InvokeHostCallback(skBitmap, events.UploadImageRequested, nameof(EditorEvents.UploadImageRequested));
                    }
                };
            }

            window.Closed += (s, e) =>
            {
                try
                {
                    onResult();
                }
                catch (Exception ex)
                {
                    EditorServices.ReportError(nameof(AvaloniaIntegration), "Failed to process editor dialog result.", ex);
                }
            };
        }

        private static void InvokeHostCallback<T>(T data, Action<T> callback, string callbackName)
        {
            try
            {
                callback(data);
            }
            catch (Exception ex)
            {
                EditorServices.ReportError(nameof(AvaloniaIntegration), $"Host callback '{callbackName}' failed.", ex);
            }
        }

        private static string? InvokeHostSaveCallback(SKBitmap skBitmap, string? filePath, Func<SKBitmap, string?, string?> callback, string callbackName)
        {
            try
            {
                return callback(skBitmap, filePath);
            }
            catch (Exception ex)
            {
                EditorServices.ReportError(nameof(AvaloniaIntegration), $"Host callback '{callbackName}' failed.", ex);
                return null;
            }
        }
    }
}