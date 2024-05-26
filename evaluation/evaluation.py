import cv2
import numpy as np
import matplotlib.pyplot as plt
import json
import os

class Evaluation:
    def __init__(self, files, save_plots) -> None:
        self.files = files
        self.save_plots = save_plots

    def rmse(self, imageA, imageB):
        
        assert imageA.shape == imageB.shape, "Images must have the same dimensions and channels"

        diff = imageA - imageB
        sq_diff = np.square(diff)
        mean_sq_diff = np.mean(sq_diff)
        rmse_value = np.sqrt(mean_sq_diff)
        return rmse_value
    
    def plot_rmse(self):
            # Ensure the save directory exists
            if not os.path.exists(self.save_plots):
                os.makedirs(self.save_plots)
                
            plt.figure(figsize=(10, 5))
            plt.title('RMSE (compared to converged delta)')
            plt.xlabel('Time (s)')
            plt.ylabel('RMSE')

            for file in self.files:
                with open(file, 'r') as f:
                    data = json.load(f)
                    times = sorted(data.keys(), key=int)  
                    times = times[:-1] # Drop 5 minutes
                    ttuv_values = [data[time]['RMSE'] for time in times]
                    plt.plot(times, ttuv_values, label=f"boundary={file.split('/')[-2].split('-')[3]}")

            plt.legend()
            plt.grid(True)
            plot_path = os.path.join(self.save_plots, 'rmse_plot.png')
            plt.savefig(plot_path)
            plt.show()
            print(f"Plot saved to {plot_path}")

if __name__ == "__main__":

    # RMSE calculation
    # eval = Evaluation(None)
    # image1 = cv2.imread('./delta-tracking/converged-5min.png')
    # image2 = cv2.imread('./weighted-delta-tracking-1.0/5min.png')
    # rmse = eval.rmse(image1, image2)
    # print("RMSE (RGB):", rmse)


    # Plot TTUV
    files = ["./weighted-delta-tracking-0.25/rmse.json",
             "./weighted-delta-tracking-0.50/rmse.json",
             "./weighted-delta-tracking-0.75/rmse.json",
             "./weighted-delta-tracking-1.0/rmse.json"]
    eval = Evaluation(files, "./plots/")
    eval.plot_rmse()