import tensorflow as tf

gpus = tf.config.list_physical_devices('GPU')

if gpus:
    print(f"✅ GPU detected: {len(gpus)} device(s)")
    for gpu in gpus:
        print("   ", gpu)
else:
    print("⚠️ No GPU detected — using CPU")