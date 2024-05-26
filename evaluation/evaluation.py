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

    def plot_ttuv(self, time):
            final_time = time  
            ttuv_values = []
            labels = []

            if not os.path.exists(self.save_plots):
                os.makedirs(self.save_plots)
            
            plt.figure(figsize=(10, 5))
            plt.title('TTUV Comparison')
            plt.xlabel('Configuration')
            plt.ylabel('TTUV')

            for file in self.files:
                with open(file, 'r') as f:
                    data = json.load(f)
                    times = sorted(data.keys(), key=int)
                    last_time = times[-1]  # Fetch the last time point, which should be 5 minutes
                    last_rmse = data[last_time]['RMSE']
                    ttuv = last_rmse * final_time
                    ttuv_values.append(ttuv)
                    label = file.split('/')[-2].split('-')[3]
                    labels.append(label)

            plt.bar(labels, ttuv_values, color='blue')
            plt.grid(True)
            plot_path = os.path.join(self.save_plots, 'ttuv_plot.png')
            plt.savefig(plot_path)
            plt.show()
            print(f"TTUV plot saved to {plot_path}")

    def plot_decomposition_rmse(self, file):
            # Ensure the save directory exists
            if not os.path.exists(self.save_plots):
                os.makedirs(self.save_plots)

            # Load RMSE data from the JSON file
            with open(file, 'r') as f:
                data = json.load(f)

            # Data preparation for plotting
            minorants = list(data.keys())
            rmse_values = [data[minorant]['RMSE'] for minorant in minorants]

            # Plotting
            plt.figure(figsize=(10, 5))
            plt.bar(minorants, rmse_values, color='red')
            plt.title('RMSE for Different Values of Minorant')
            plt.xlabel('Minorant')
            plt.ylabel('RMSE')
            plt.grid(True)

            # Adjusting the y-axis to zoom in more on the range of interest
            min_rmse = min(rmse_values)
            max_rmse = max(rmse_values)
            plt.ylim(min_rmse * 0.95, max_rmse * 1.05)  # Adjust to 95% of the minimum and 105% of the maximum RMSE

            # Save and show plot
            plot_path = os.path.join(self.save_plots, 'decomposition_rmse_plot.png')
            plt.savefig(plot_path)
            plt.show()
            print(f"Decomposition RMSE plot saved to {plot_path}")
            
if __name__ == "__main__":

    # RMSE calculation
    # eval = Evaluation(None, None)
    # image1 = cv2.imread('./delta-tracking/converged-5min.png')
    # image2 = cv2.imread('./decomposition-tracking/005Minorant.png')
    # rmse = eval.rmse(image1, image2)
    # print("RMSE (RGB):", rmse)


    # Plot RMSE
    # files = ["./weighted-delta-tracking-0.25/rmse.json",
    #          "./weighted-delta-tracking-0.50/rmse.json",
    #          "./weighted-delta-tracking-0.75/rmse.json",
    #          "./weighted-delta-tracking-1.0/rmse.json"]
    # eval = Evaluation(files, "./plots/")
    # eval.plot_rmse()

    # Calculate TTUV
    # files = ["./weighted-delta-tracking-0.25/rmse.json",
    #          "./weighted-delta-tracking-0.50/rmse.json",
    #          "./weighted-delta-tracking-0.75/rmse.json",
    #          "./weighted-delta-tracking-1.0/rmse.json"]
    
    # eval = Evaluation(files, "./plots/")

    # eval.plot_ttuv(time=500)


    # Plot decomposition RMSE
    eval = Evaluation(None, "./plots/")
    eval.plot_decomposition_rmse('./decomposition-tracking/rmse.json')