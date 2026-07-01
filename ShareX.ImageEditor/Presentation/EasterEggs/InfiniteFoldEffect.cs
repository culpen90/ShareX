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

namespace ShareX.ImageEditor.Presentation.EasterEggs;

/// <summary>
/// SkSL port of the supplied iterative folded-space shader. Its light output is screen-blended
/// over the flattened editor image instead of replacing the image with an opaque black field.
/// </summary>
internal sealed class InfiniteFoldEffect : IShaderEasterEggEffect
{
    public string ShaderSource => """
        uniform shader source;
        uniform float2 resolution;
        uniform float time;
        uniform float progress;

        float2x2 rotate2D(float angle)
        {
            return float2x2(cos(angle), sin(angle), -sin(angle), cos(angle));
        }

        float3x3 rotate3D(float angle, float3 axis)
        {
            float3 a = normalize(axis);
            float sine = sin(angle);
            float cosine = cos(angle);
            float remainder = 1.0 - cosine;
            return float3x3(
                a.x * a.x * remainder + cosine,
                a.y * a.x * remainder + a.z * sine,
                a.z * a.x * remainder - a.y * sine,
                a.x * a.y * remainder - a.z * sine,
                a.y * a.y * remainder + cosine,
                a.z * a.y * remainder + a.x * sine,
                a.x * a.z * remainder + a.y * sine,
                a.y * a.z * remainder - a.x * sine,
                a.z * a.z * remainder + cosine);
        }

        half4 main(float2 position)
        {
            position.y = resolution.y - position.y;
            float4 outputColor = float4(0.0);
            float2 size = resolution;
            float3 seed = float3(1.0, 3.0, 7.0);
            float3 point = float3(0.0);
            float iterationVariant = 0.0;
            float stepDistance = 0.0;
            float travel = 0.0;
            float rotation = time * 0.2;

            for (int rayStep = 0; rayStep < 100; ++rayStep)
            {
                point = float3((position - size * 0.5) / size.y * travel, travel) *
                    rotate3D(rotation, cos(rotation + seed));
                point.z += time;
                point = asin(sin(point)) - 3.0;
                iterationVariant = 0.0;

                for (int fold = 0; fold < 9; ++fold)
                {
                    point.xz = point.xz * rotate2D(travel / 8.0);
                    point = abs(point);
                    if (point.x < point.y)
                    {
                        iterationVariant += 1.0;
                        point = point.zxy;
                    }
                    else
                    {
                        point = point.zyx;
                    }

                    point += point - seed;
                }

                stepDistance = max(point.x, point.z) / 1000.0 - 0.01;
                travel += stepDistance;
                outputColor.rgb += 0.1 /
                    exp(cos(seed * travel * 0.1 + iterationVariant) + 3.0 + 10000.0 * stepDistance);
            }

            half4 background = source.eval(float2(position.x, resolution.y - position.y));
            float fade = smoothstep(0.0, 0.06, progress) *
                (1.0 - smoothstep(0.90, 1.0, progress));
            half3 glow = half3(clamp(outputColor.rgb * 1.3, float3(0.0), float3(1.0))) * half(fade);

            // Screen blend preserves the flattened editor snapshot as the background.
            half3 composited = background.rgb + glow * (half3(background.a) - background.rgb);
            return half4(min(composited, half3(background.a)), background.a);
        }
        """;

    public TimeSpan Duration => TimeSpan.FromSeconds(12);

    public int FramesPerSecond => 60;
}
