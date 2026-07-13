export type Layer = {
	name: string,
	editImage: EditableImage,
	offset: Vector2,
	tintColor: Color3,
	transparency: number,
}

-- A color grade applied to the composited result (not per-layer). Identity is
-- brightness 0, contrast 0, saturation 0, hue 0.
export type Adjustment = {
	brightness: number,
	contrast: number,
	saturation: number,
	hue: number,
}

-- A parsed 3D `.cube` color lookup table applied to the composited result after the
-- grade. `data` is a flat f32 buffer of `size^3` RGB triples in red-fastest order (the
-- native `.cube` data order), so a sample at grid coords (r, g, b) lives at
-- `((b * size + g) * size + r) * 3`. `id` changes on every import so caches can detect
-- swaps; it is never persisted (LUTs are live-only, stripped from preset snapshots).
export type Lut = {
	id: string,
	name: string,
	size: number,
	data: buffer,
	domainMin: Vector3,
	domainMax: Vector3,
}

return {}
