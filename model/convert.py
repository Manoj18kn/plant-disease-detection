import tensorflow as tf

# Load saved model
model = tf.keras.models.load_model('best_model.h5')

# Save class names
class_names = [
    'Corn_Common_Rust',
    'Corn_Gray_Leaf_Spot', 
    'Corn_Healthy',
    'Corn_Northern_Blight',
    'Tomato_Bacterial_Spot',
    'Tomato_Early_Blight',
    'Tomato_Healthy',
    'Tomato_Late_Blight',
    'Tomato_Leaf_Mold',
    'Tomato_Mosaic_Virus',
    'Tomato_Septoria_Leaf_Spot',
    'Tomato_Spider_Mites',
    'Tomato_Target_Spot',
    'Tomato_Yellow_Leaf_Curl'
]

with open('class_names.txt', 'w') as f:
    for name in class_names:
        f.write(name + '\n')

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open('crop_disease_model.tflite', 'wb') as f:
    f.write(tflite_model)

print("✅ crop_disease_model.tflite saved!")
print("✅ class_names.txt saved!")