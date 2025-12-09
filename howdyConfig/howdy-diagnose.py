#!/usr/bin/env python3
"""Howdy Face Recognition Diagnostic Tool - Verbose Edition"""

import sys
import time

print("=" * 60)
print("Howdy Face Recognition Diagnostic (Verbose)")
print("=" * 60)
print()
print(f"[{time.time():.2f}] Starting diagnostic...")
sys.stdout.flush()

print(f"[{time.time():.2f}] Importing cv2...")
sys.stdout.flush()
import cv2
print(f"[{time.time():.2f}] cv2 imported OK")
sys.stdout.flush()

print(f"[{time.time():.2f}] Importing json...")
sys.stdout.flush()
import json
print(f"[{time.time():.2f}] json imported OK")
sys.stdout.flush()

print(f"[{time.time():.2f}] Importing numpy...")
sys.stdout.flush()
import numpy as np
print(f"[{time.time():.2f}] numpy imported OK")
sys.stdout.flush()

print(f"[{time.time():.2f}] Importing face_recognition (this can take a while)...")
sys.stdout.flush()
try:
    import face_recognition
    print(f"[{time.time():.2f}] face_recognition imported OK")
    sys.stdout.flush()
except ImportError as e:
    print(f"[{time.time():.2f}] ERROR: face_recognition not installed: {e}")
    sys.exit(1)

CAMERA_DEVICE = "/dev/video2"
MODEL_FILE = "/lib/security/howdy/models/jishua9.dat"
CERTAINTY = 4.0

def load_models():
    """Load saved face encodings"""
    print(f"[{time.time():.2f}] Opening model file: {MODEL_FILE}")
    sys.stdout.flush()
    try:
        with open(MODEL_FILE, 'r') as f:
            data = json.load(f)
        print(f"[{time.time():.2f}] JSON parsed, {len(data)} entries")
        sys.stdout.flush()

        encodings = []
        labels = []
        for entry in data:
            encodings.append(np.array(entry['data'][0]))
            labels.append(entry['label'])
        return encodings, labels
    except Exception as e:
        print(f"[{time.time():.2f}] ERROR loading models: {e}")
        sys.stdout.flush()
        return [], []

def main():
    print()
    print(f"[{time.time():.2f}] === Step 1: Loading saved face models ===")
    sys.stdout.flush()

    encodings, labels = load_models()
    print(f"[{time.time():.2f}] Loaded {len(encodings)} face model(s): {labels}")
    sys.stdout.flush()

    if not encodings:
        print(f"[{time.time():.2f}] ERROR: No face models found!")
        return

    print()
    print(f"[{time.time():.2f}] === Step 2: Opening camera ===")
    print(f"[{time.time():.2f}] Attempting to open {CAMERA_DEVICE}...")
    sys.stdout.flush()

    cap = cv2.VideoCapture(CAMERA_DEVICE)

    print(f"[{time.time():.2f}] VideoCapture object created")
    sys.stdout.flush()

    if not cap.isOpened():
        print(f"[{time.time():.2f}] ERROR: Cannot open camera {CAMERA_DEVICE}")
        return

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    print(f"[{time.time():.2f}] Camera opened: {width}x{height} @ {fps}fps")
    sys.stdout.flush()

    print()
    print(f"[{time.time():.2f}] === Step 3: Capturing frames ===")
    print(f"[{time.time():.2f}] Please look at the camera...")
    sys.stdout.flush()

    for attempt in range(10):
        print(f"[{time.time():.2f}] Attempt {attempt+1}/10: Reading frame...")
        sys.stdout.flush()

        ret, frame = cap.read()

        if not ret:
            print(f"[{time.time():.2f}] Attempt {attempt+1}: Failed to capture frame")
            sys.stdout.flush()
            time.sleep(0.3)
            continue

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Frame captured, shape={frame.shape}")
        sys.stdout.flush()

        avg_brightness = np.mean(frame)
        print(f"[{time.time():.2f}] Attempt {attempt+1}: Brightness={avg_brightness:.1f}")
        sys.stdout.flush()

        if avg_brightness < 30:
            print(f"[{time.time():.2f}] Attempt {attempt+1}: Frame too dark, skipping")
            sys.stdout.flush()
            time.sleep(0.3)
            continue

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Converting to RGB...")
        sys.stdout.flush()

        if len(frame.shape) == 2:  # Greyscale
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2RGB)
        else:
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        print(f"[{time.time():.2f}] Attempt {attempt+1}: RGB conversion done, shape={rgb_frame.shape}")
        sys.stdout.flush()

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Detecting faces (this may take a moment)...")
        sys.stdout.flush()

        start_detect = time.time()
        face_locations = face_recognition.face_locations(rgb_frame)
        detect_time = time.time() - start_detect

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Face detection took {detect_time:.2f}s, found {len(face_locations)} face(s)")
        sys.stdout.flush()

        if not face_locations:
            print(f"[{time.time():.2f}] Attempt {attempt+1}: No face detected")
            sys.stdout.flush()
            time.sleep(0.3)
            continue

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Face locations: {face_locations}")
        sys.stdout.flush()

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Encoding face...")
        sys.stdout.flush()

        start_encode = time.time()
        face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)
        encode_time = time.time() - start_encode

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Face encoding took {encode_time:.2f}s, got {len(face_encodings)} encoding(s)")
        sys.stdout.flush()

        if not face_encodings:
            print(f"[{time.time():.2f}] Attempt {attempt+1}: Could not encode face")
            sys.stdout.flush()
            time.sleep(0.3)
            continue

        print(f"[{time.time():.2f}] Attempt {attempt+1}: Comparing with saved models...")
        sys.stdout.flush()

        for face_enc in face_encodings:
            distances = face_recognition.face_distance(encodings, face_enc)

            print()
            print(f"[{time.time():.2f}] Face distances to saved models:")
            sys.stdout.flush()

            for i, (dist, label) in enumerate(zip(distances, labels)):
                howdy_score = dist * 10
                match_status = "MATCH" if howdy_score <= CERTAINTY else "NO MATCH"
                print(f"           {label}: {dist:.4f} (score: {howdy_score:.2f}) [{match_status}]")
                sys.stdout.flush()

            best_idx = np.argmin(distances)
            best_dist = distances[best_idx]
            best_label = labels[best_idx]
            best_score = best_dist * 10

            print()
            if best_score <= CERTAINTY:
                print(f"[{time.time():.2f}] >>> SUCCESS: Would authenticate as '{best_label}' (score {best_score:.2f} <= {CERTAINTY})")
            else:
                print(f"[{time.time():.2f}] >>> FAIL: Best score {best_score:.2f} > certainty {CERTAINTY}")
                print(f"[{time.time():.2f}]     Suggestion: Increase certainty to {best_score + 0.5:.1f} or re-add face models")
            sys.stdout.flush()

        # Success - we got a result
        break

    print()
    print(f"[{time.time():.2f}] Releasing camera...")
    sys.stdout.flush()
    cap.release()

    print(f"[{time.time():.2f}] Done!")
    print()
    print("=" * 60)
    print("Diagnostic complete")
    print("=" * 60)
    sys.stdout.flush()

if __name__ == "__main__":
    main()
