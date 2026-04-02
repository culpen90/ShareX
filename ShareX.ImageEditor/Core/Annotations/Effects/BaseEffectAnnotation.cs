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

using SkiaSharp;

namespace ShareX.ImageEditor.Core.Annotations;

/// <summary>
/// Base class for effect annotations (Blur, Pixelate, Highlight)
/// </summary>
public abstract class BaseEffectAnnotation : Annotation, IDisposable
{
    public override AnnotationCategory Category => AnnotationCategory.Effects;

    /// <summary>
    /// Effect radius / strength
    /// </summary>
    public float Amount { get; set; } = 10;

    /// <summary>
    /// Whether the effect is applied as a region (rectangle) or freehand
    /// </summary>
    public bool IsFreehand { get; set; }

    /// <summary>
    /// The generated bitmap for the effect (pre-rendered effect result)
    /// </summary>
    public SKBitmap? EffectBitmap { get; protected set; }

    public override SKRect GetBounds()
    {
        return new SKRect(
            Math.Min(StartPoint.X, EndPoint.X),
            Math.Min(StartPoint.Y, EndPoint.Y),
            Math.Max(StartPoint.X, EndPoint.X),
            Math.Max(StartPoint.Y, EndPoint.Y));
    }

    public override bool HitTest(SKPoint point, float tolerance = 5)
    {
        var bounds = GetBounds();
        var inflatedBounds = SKRect.Inflate(bounds, tolerance, tolerance);
        return inflatedBounds.Contains(point);
    }

    public override Annotation Clone()
    {
        var clone = (BaseEffectAnnotation)base.Clone();
        // Don't copy the bitmap - it will be regenerated when needed
        // This avoids shared bitmap references and potential disposal issues
        clone.EffectBitmap = null;
        return clone;
    }

    /// <summary>
    /// Updates the effect bitmap based on the source image
    /// </summary>
    public virtual void UpdateEffect(SKBitmap source) { }

    /// <summary>
    /// Disposes the effect bitmap
    /// </summary>
    public void DisposeEffect()
    {
        EffectBitmap?.Dispose();
        EffectBitmap = null;
    }

    /// <summary>
    /// Dispose unmanaged resources (EffectBitmap)
    /// </summary>
    public void Dispose()
    {
        DisposeEffect();
        GC.SuppressFinalize(this);
    }
}