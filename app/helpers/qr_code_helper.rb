module QrCodeHelper
  # Inline SVG QR code. Uses currentColor so CSS controls the color.
  def qr_code_svg(url, size: 160, label: nil)
    svg = RQRCode::QRCode.new(url, level: :m).as_svg(
      color: "currentColor",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: { width: size, height: size, role: "img", "aria-label": label || url }
    )
    svg.html_safe
  end
end
