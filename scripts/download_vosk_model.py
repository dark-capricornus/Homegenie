import os
import requests
import zipfile
import io
import shutil

def download_model(model_name="vosk-model-small-en-us-0.15", target_dir="models/vosk"):
    """
    Downloads and extracts a Vosk model.
    """
    url = f"https://alphacephei.com/vosk/models/{model_name}.zip"
    
    if os.path.exists(target_dir):
        print(f"Model directory {target_dir} already exists. Skipping download.")
        return

    print(f"Downloading model from {url}...")
    response = requests.get(url)
    
    if response.status_code == 200:
        print("Extracting model...")
        with zipfile.ZipFile(io.BytesIO(response.content)) as zip_ref:
            # Extract to a temporary directory first to handle the nested folder in the zip
            temp_extract_dir = "models/temp_vosk"
            zip_ref.extractall(temp_extract_dir)
            
            # The zip usually contains a folder with the model name
            source_folder = os.path.join(temp_extract_dir, model_name)
            
            if not os.path.exists(os.path.dirname(target_dir)):
                os.makedirs(os.path.dirname(target_dir))
                
            shutil.move(source_folder, target_dir)
            shutil.rmtree(temp_extract_dir)
            print(f"Model successfully installed to {target_dir}")
    else:
        print(f"Failed to download model. Status code: {response.status_code}")

if __name__ == "__main__":
    download_model()
