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

using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using SkiaSharp;

namespace ShareX.ImageEditor.Core.BackgroundRemoval;

public sealed class BackgroundRemovalService
{
    private const string ModelRelativePath = "Assets/u2netp.onnx";
    private static readonly float[] Mean = [0.485f, 0.456f, 0.406f];
    private static readonly float[] StandardDeviation = [0.229f, 0.224f, 0.225f];

    public SKBitmap RemoveBackground(SKBitmap source)
    {
        ArgumentNullException.ThrowIfNull(source);

        if (source.Width <= 0 || source.Height <= 0)
        {
            throw new InvalidOperationException("Selected image is empty.");
        }

        string modelPath = GetModelPath();
        if (!File.Exists(modelPath))
        {
            throw new FileNotFoundException("The background removal model file is missing.", modelPath);
        }

        using InferenceSession session = new(modelPath);
        string inputName = session.InputMetadata.Keys.FirstOrDefault()
            ?? throw new InvalidOperationException("The ONNX model does not expose an input tensor.");

        int inputWidth;
        int inputHeight;
        bool channelsLast;
        ResolveInputShape(session.InputMetadata[inputName].Dimensions, out inputWidth, out inputHeight, out channelsLast);

        using SKBitmap inputBitmap = ResizeBitmap(source, inputWidth, inputHeight);
        DenseTensor<float> inputTensor = CreateInputTensor(inputBitmap, channelsLast);

        using IDisposableReadOnlyCollection<DisposableNamedOnnxValue> outputs = session.Run(
        [
            NamedOnnxValue.CreateFromTensor(inputName, inputTensor)
        ]);

        Tensor<float> outputTensor = outputs.FirstOrDefault()?.AsTensor<float>()
            ?? throw new InvalidOperationException("The ONNX model did not return a usable output tensor.");

        using SKBitmap modelMask = CreateMaskBitmap(outputTensor);
        using SKBitmap resizedMask = ResizeBitmap(modelMask, source.Width, source.Height);
        return ApplyAlphaMask(source, resizedMask);
    }

    private static string GetModelPath()
    {
        return Path.Combine(AppContext.BaseDirectory, ModelRelativePath);
    }

    private static void ResolveInputShape(IReadOnlyList<int> dimensions, out int width, out int height, out bool channelsLast)
    {
        width = 320;
        height = 320;
        channelsLast = false;

        if (dimensions.Count != 4)
        {
            return;
        }

        int channelIndex = dimensions[1] == 3 ? 1 : dimensions[3] == 3 ? 3 : 1;
        channelsLast = channelIndex == 3;

        int heightIndex = channelsLast ? 1 : 2;
        int widthIndex = channelsLast ? 2 : 3;

        if (dimensions[heightIndex] > 0)
        {
            height = dimensions[heightIndex];
        }

        if (dimensions[widthIndex] > 0)
        {
            width = dimensions[widthIndex];
        }
    }

    private static DenseTensor<float> CreateInputTensor(SKBitmap bitmap, bool channelsLast)
    {
        DenseTensor<float> tensor = channelsLast
            ? new DenseTensor<float>([1, bitmap.Height, bitmap.Width, 3])
            : new DenseTensor<float>([1, 3, bitmap.Height, bitmap.Width]);

        for (int y = 0; y < bitmap.Height; y++)
        {
            for (int x = 0; x < bitmap.Width; x++)
            {
                SKColor color = bitmap.GetPixel(x, y);
                float r = ((color.Red / 255f) - Mean[0]) / StandardDeviation[0];
                float g = ((color.Green / 255f) - Mean[1]) / StandardDeviation[1];
                float b = ((color.Blue / 255f) - Mean[2]) / StandardDeviation[2];

                if (channelsLast)
                {
                    tensor[0, y, x, 0] = r;
                    tensor[0, y, x, 1] = g;
                    tensor[0, y, x, 2] = b;
                }
                else
                {
                    tensor[0, 0, y, x] = r;
                    tensor[0, 1, y, x] = g;
                    tensor[0, 2, y, x] = b;
                }
            }
        }

        return tensor;
    }

    private static SKBitmap CreateMaskBitmap(Tensor<float> outputTensor)
    {
        int height = 1;
        int width = 1;

        if (outputTensor.Dimensions.Length >= 4)
        {
            height = outputTensor.Dimensions[^2];
            width = outputTensor.Dimensions[^1];
        }
        else if (outputTensor.Dimensions.Length >= 2)
        {
            height = outputTensor.Dimensions[^2];
            width = outputTensor.Dimensions[^1];
        }

        if (width <= 0 || height <= 0)
        {
            throw new InvalidOperationException("The ONNX model returned an invalid mask size.");
        }

        float[] values = outputTensor.ToArray();
        int pixelCount = width * height;

        if (values.Length < pixelCount)
        {
            throw new InvalidOperationException("The ONNX model returned an incomplete mask.");
        }

        float min = float.MaxValue;
        float max = float.MinValue;

        for (int i = 0; i < pixelCount; i++)
        {
            float value = values[i];
            if (value < min) min = value;
            if (value > max) max = value;
        }

        float range = Math.Max(0.000001f, max - min);
        SKBitmap mask = new(new SKImageInfo(width, height, SKColorType.Bgra8888, SKAlphaType.Premul));

        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                int index = (y * width) + x;
                float normalized = Math.Clamp((values[index] - min) / range, 0f, 1f);
                byte alpha = (byte)MathF.Round(normalized * 255f);
                mask.SetPixel(x, y, new SKColor(alpha, alpha, alpha, alpha));
            }
        }

        return mask;
    }

    private static SKBitmap ApplyAlphaMask(SKBitmap source, SKBitmap mask)
    {
        SKBitmap output = new(new SKImageInfo(source.Width, source.Height, SKColorType.Bgra8888, SKAlphaType.Premul));

        for (int y = 0; y < source.Height; y++)
        {
            for (int x = 0; x < source.Width; x++)
            {
                SKColor sourceColor = source.GetPixel(x, y);
                byte maskAlpha = mask.GetPixel(x, y).Alpha;
                byte outputAlpha = (byte)Math.Clamp((int)MathF.Round(sourceColor.Alpha * (maskAlpha / 255f)), 0, 255);

                output.SetPixel(x, y, new SKColor(sourceColor.Red, sourceColor.Green, sourceColor.Blue, outputAlpha));
            }
        }

        return output;
    }

    private static SKBitmap ResizeBitmap(SKBitmap source, int width, int height)
    {
        if (source.Width == width && source.Height == height)
        {
            return source.Copy();
        }

        SKBitmap resized = new(new SKImageInfo(width, height, SKColorType.Bgra8888, SKAlphaType.Premul));

        using SKCanvas canvas = new(resized);
        using SKPaint paint = new() { IsAntialias = true };
        using SKImage sourceImage = SKImage.FromBitmap(source);
        canvas.Clear(SKColors.Transparent);
        canvas.DrawImage(sourceImage, new SKRect(0, 0, width, height), new SKSamplingOptions(SKCubicResampler.CatmullRom), paint);

        return resized;
    }
}
