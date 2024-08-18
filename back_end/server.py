from flask import Flask, request, jsonify
import numpy as np
import cv2

app = Flask(__name__)

def moving_average_filter(data, window_size):
    return np.convolve(data, np.ones(window_size) / window_size, mode='valid')

def detect_peaks(signal, threshold=0.3):  # Increased sensitivity by lowering the threshold
    peaks = []
    for i in range(1, len(signal) - 1):
        if signal[i] > signal[i - 1] and signal[i] > signal[i + 1] and signal[i] > threshold:
            peaks.append(i)
    return np.array(peaks)

@app.route('/process_video', methods=['POST'])
def process_video():
    try:
        file = request.files['video']
        video_path = './temp_video.mp4'
        file.save(video_path)

        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)

        intensities = []
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            intensities.append(np.mean(gray))
        cap.release()

        signal = np.array(intensities)
        filtered_signal = moving_average_filter(signal, window_size=5)

        # Peak detection with increased sensitivity
        mean_intensity = np.mean(filtered_signal)
        std_intensity = np.std(filtered_signal)
        threshold = mean_intensity + 0.3 * std_intensity  # Lower threshold for more sensitivity
        peaks = detect_peaks(filtered_signal, threshold=threshold)

        if len(peaks) > 1:
            peak_intervals = np.diff(peaks) / fps * 60.0
            heart_rate = np.mean(peak_intervals)
        else:
            heart_rate = 0.0

        return jsonify({'heart_rate': heart_rate, 'peaks': peaks.tolist()})

    except Exception as e:
        print(f"Error processing signal: {e}")
        return jsonify({'heart_rate': 0.0, 'peaks': []})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
