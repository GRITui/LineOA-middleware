type Bar = { label: string; value: number };

type BarChartProps = {
  data: Bar[];
  width?: number;
  height?: number;
  barColor?: string;
};

export default function BarChart({
  data,
  width = 600,
  height = 300,
  barColor = '#4f46e5'
}: BarChartProps) {
  if (data.length === 0) return null;

  const maxVal = Math.max(...data.map(d => d.value));
  const barWidth = width / data.length - 10;
  const chartPadding = 30;

  return (
    <svg width={width} height={height} className="overflow-visible">
      {data.map((d, i) => {
        const x = chartPadding + i * (barWidth + 10) + barWidth / 2;
        return (
          <text
            key={i}
            x={x}
            y={height - 5}
            textAnchor="middle"
            fontSize="10"
            fill="#555"
          >
            {new Date(d.label).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
          </text>
        );
      })}

      {data.map((d, i) => {
        const barHeight = (d.value / maxVal) * (height - chartPadding * 2);
        const x = chartPadding + i * (barWidth + 10);
        const y = height - chartPadding - barHeight;
        return (
          <g key={i}>
            <rect
              x={x}
              y={y}
              width={barWidth}
              height={barHeight}
              fill={barColor}
            />
            <text
              x={x + barWidth / 2}
              y={y - 4}
              textAnchor="middle"
              fontSize="10"
              fill="#333"
            >
              {d.value}
            </text>
          </g>
        );
      })}

      <line
        x1={chartPadding}
        y1={height - chartPadding}
        x2={chartPadding}
        y2={chartPadding}
        stroke="#333"
        strokeWidth="1"
      />
    </svg>
  );
}