#!/bin/bash
# Create BOLD icons optimized for Chrome toolbar visibility

echo "🎤 Creating bold MindFlow icons..."
cd "$(dirname "$0")"

# Create MUCH simpler and bolder SVG - almost icon-sized shapes
cat > icon.svg << 'SVGEOF'
<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg">
  <!-- Solid blue background -->
  <rect width="128" height="128" fill="#007AFF" rx="20"/>
  
  <!-- VERY BOLD white microphone - maximum visibility -->
  <g fill="white">
    <!-- Large mic capsule (pill shape) -->
    <rect x="42" y="28" width="44" height="52" rx="22" fill="white"/>
    
    <!-- Extra thick stand -->
    <rect x="54" y="80" width="20" height="22" fill="white"/>
    
    <!-- Very wide base -->
    <rect x="36" y="102" width="56" height="14" rx="7" fill="white"/>
  </g>
</svg>
SVGEOF

# Generate all sizes
for size in 128 48 32 16; do
  qlmanage -t -s $size -o . icon.svg > /dev/null 2>&1
  if [ -f "icon.svg.png" ]; then
    mv icon.svg.png icon-${size}.png
    echo "✓ Created icon-${size}.png"
  fi
done

rm icon.svg

echo ""
echo "✅ Bold icons created!"
