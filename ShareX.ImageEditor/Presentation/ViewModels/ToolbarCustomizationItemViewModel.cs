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

using ShareX.ImageEditor.Core.Annotations;
using ShareX.ImageEditor.Hosting;
using ShareX.ImageEditor.Presentation.Theming;

namespace ShareX.ImageEditor.Presentation.ViewModels;

public sealed class ToolbarCustomizationItemViewModel : ViewModelBase
{
    private sealed record ToolDefinition(EditorTool Tool, string Name, string Icon, string DefaultHotkey);

    private static readonly IReadOnlyList<ToolDefinition> ToolDefinitions = new[]
    {
        new ToolDefinition(EditorTool.Select, "Select", EditorIcons.ToolSelect, "V"),
        new ToolDefinition(EditorTool.Rectangle, "Rectangle", EditorIcons.ToolRectangle, "R"),
        new ToolDefinition(EditorTool.Ellipse, "Ellipse", EditorIcons.ToolEllipse, "E"),
        new ToolDefinition(EditorTool.Line, "Line", EditorIcons.ToolLine, "L"),
        new ToolDefinition(EditorTool.Arrow, "Arrow", EditorIcons.ToolArrow, "A"),
        new ToolDefinition(EditorTool.Freehand, "Freehand", EditorIcons.ToolFreehand, "F"),
        new ToolDefinition(EditorTool.Text, "Text", EditorIcons.ToolText, "T"),
        new ToolDefinition(EditorTool.SpeechBalloon, "Speech Balloon", EditorIcons.ToolSpeechBalloon, "O"),
        new ToolDefinition(EditorTool.Step, "Step", EditorIcons.ToolStep, "N"),
        new ToolDefinition(EditorTool.Image, "Image", EditorIcons.ToolImage, "I"),
        new ToolDefinition(EditorTool.Emoji, "Emoji", EditorIcons.ToolEmoji, "J"),
        new ToolDefinition(EditorTool.Cursor, "Cursor", EditorIcons.ToolCursor, "K"),
        new ToolDefinition(EditorTool.Highlight, "Highlight", EditorIcons.ToolHighlight, "H"),
        new ToolDefinition(EditorTool.SmartEraser, "Smart Eraser", EditorIcons.ToolSmartEraser, "W"),
        new ToolDefinition(EditorTool.Blur, "Blur", EditorIcons.ToolBlur, "B"),
        new ToolDefinition(EditorTool.Pixelate, "Pixelate", EditorIcons.ToolPixelate, "P"),
        new ToolDefinition(EditorTool.Magnify, "Magnify", EditorIcons.ToolMagnify, "M"),
        new ToolDefinition(EditorTool.Spotlight, "Spotlight", EditorIcons.ToolSpotlight, "S"),
        new ToolDefinition(EditorTool.Crop, "Crop", EditorIcons.ToolCrop, "C"),
        new ToolDefinition(EditorTool.CutOut, "Cut Out", EditorIcons.ToolCutOut, "U")
    };

    private static readonly IReadOnlyDictionary<string, ToolDefinition> ToolDefinitionsById =
        ToolDefinitions.ToDictionary(definition => GetToolId(definition.Tool), StringComparer.OrdinalIgnoreCase);

    private bool _isVisible = true;
    private bool _isActive;
    private bool _canMoveUp;
    private bool _canMoveDown;
    private bool _beginGroup;
    private string _hotkey = "";

    private ToolbarCustomizationItemViewModel(
        string id,
        EditorTool tool,
        string name,
        string icon,
        string hotkey,
        bool isVisible,
        bool beginGroup)
    {
        Id = id;
        Tool = tool;
        Name = name;
        Icon = icon;
        _hotkey = hotkey;
        _isVisible = isVisible;
        _beginGroup = beginGroup;
    }

    public string Id { get; }
    public bool IsTool => true;
    public EditorTool Tool { get; }
    public string Name { get; }
    public string Icon { get; }

    public bool IsVisible
    {
        get => _isVisible;
        set
        {
            if (SetProperty(ref _isVisible, value))
            {
                OnPropertyChanged(nameof(IsButtonVisible));
                OnPropertyChanged(nameof(IsGroupSeparatorVisible));
            }
        }
    }

    public string Hotkey
    {
        get => _hotkey;
        set
        {
            if (SetProperty(ref _hotkey, value ?? ""))
            {
                OnPropertyChanged(nameof(ToolTip));
            }
        }
    }

    public bool IsActive
    {
        get => _isActive;
        set => SetProperty(ref _isActive, value);
    }

    public bool CanMoveUp
    {
        get => _canMoveUp;
        set => SetProperty(ref _canMoveUp, value);
    }

    public bool CanMoveDown
    {
        get => _canMoveDown;
        set => SetProperty(ref _canMoveDown, value);
    }

    public bool BeginGroup
    {
        get => _beginGroup;
        set
        {
            if (SetProperty(ref _beginGroup, value))
            {
                OnPropertyChanged(nameof(IsGroupSeparatorVisible));
            }
        }
    }

    public bool IsButtonVisible => IsVisible;
    public bool IsGroupSeparatorVisible => IsVisible && BeginGroup;

    public string ToolTip
    {
        get
        {
            string hotkey = Hotkey.Trim();
            return hotkey.Length > 0 ? $"{Name} ({hotkey})" : Name;
        }
    }

    public ToolbarCustomizationItemViewModel Clone()
    {
        return new ToolbarCustomizationItemViewModel(Id, Tool, Name, Icon, Hotkey, IsVisible, BeginGroup)
        {
            IsActive = IsActive,
            CanMoveUp = CanMoveUp,
            CanMoveDown = CanMoveDown
        };
    }

    public ImageEditorToolbarItemOptions ToOptions()
    {
        return new ImageEditorToolbarItemOptions
        {
            Id = Id,
            BeginGroup = BeginGroup,
            IsVisible = IsVisible,
            Hotkey = Hotkey.Trim()
        };
    }

    public static IReadOnlyList<ToolbarCustomizationItemViewModel> CreateDefaultItems()
    {
        return ToolDefinitions.Select(definition => CreateTool(definition)).ToList();
    }

    public static IReadOnlyList<ToolbarCustomizationItemViewModel> CreateFromOptions(IReadOnlyList<ImageEditorToolbarItemOptions>? options)
    {
        if (options == null || options.Count == 0)
        {
            return CreateDefaultItems();
        }

        List<ToolbarCustomizationItemViewModel> items = new();
        HashSet<string> usedToolIds = new(StringComparer.OrdinalIgnoreCase);

        foreach (ImageEditorToolbarItemOptions option in options)
        {
            if (ToolDefinitionsById.TryGetValue(option.Id, out ToolDefinition? definition))
            {
                items.Add(CreateTool(definition, option.IsVisible, option.Hotkey ?? definition.DefaultHotkey, option.BeginGroup));
                usedToolIds.Add(option.Id);
            }
        }

        foreach (ToolDefinition missingDefinition in ToolDefinitions.Where(definition => !usedToolIds.Contains(GetToolId(definition.Tool))))
        {
            items.Add(CreateTool(missingDefinition));
        }

        return items.Count > 0 ? items : CreateDefaultItems();
    }

    private static ToolbarCustomizationItemViewModel CreateTool(ToolDefinition definition, bool isVisible = true, string? hotkey = null, bool? beginGroup = null)
    {
        return new ToolbarCustomizationItemViewModel(
            GetToolId(definition.Tool),
            definition.Tool,
            definition.Name,
            definition.Icon,
            hotkey ?? definition.DefaultHotkey,
            isVisible,
            beginGroup ?? definition.Tool is EditorTool.Select or EditorTool.Crop);
    }

    private static string GetToolId(EditorTool tool) => tool.ToString();
}
