// 나무·풀이 바람에 흔들리는 효과. amp = 흔들림 크기, speed = 빠르기, hang = 위에서 늘어진 가지(아래가 흔들림)
shader_type canvas_item;
uniform float amp = 4.0;
uniform float speed = 1.0;
uniform bool hang = false;
void vertex() {
	float k = hang ? UV.y : 1.0 - UV.y;
	float ph = MODEL_MATRIX[3].x * 0.013;
	VERTEX.x += (sin(TIME * speed + ph) + 0.35 * sin(TIME * speed * 2.3 + ph * 1.7)) * amp * pow(k, 1.5);
}
