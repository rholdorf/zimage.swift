.build/xcode/Build/Products/Release/ZImageCLI \
	-p "a woman" \
	--lora ~/src/pg/ComfyUI/models/loras/daniela/dm4_000007000.safetensors \
	--lora-scale 0.5 \
	--lora ~/src/pg/ComfyUI/models/loras/daniela/daniela_monzillo.safetensors \
	--lora-scale 0.5 \
	-o ./output/woman2.png

