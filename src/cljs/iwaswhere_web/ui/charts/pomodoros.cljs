(ns iwaswhere-web.ui.charts.pomodoros
  (:require [reagent.core :as rc]
            [iwaswhere-web.ui.charts.common :as cc]
            [iwaswhere-web.utils.misc :as u]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [clojure.pprint :as pp]))

(defn bars
  [indexed local k chart-h y-scale put-fn]
  [:g
   (for [[idx v] indexed]
     (let [h (* y-scale (k v))
           mouse-enter-fn (cc/mouse-enter-fn local v)
           mouse-leave-fn (cc/mouse-leave-fn local v)]
       ^{:key (str "pbar" k idx)}
       [:rect {:class          (cc/weekend-class (name k) v)
               :on-click       (cc/open-day-fn v put-fn)
               :x              (* 10 idx)
               :y              (- chart-h h)
               :width          9
               :height         h
               :on-mouse-enter mouse-enter-fn
               :on-mouse-leave mouse-leave-fn}]))])

(defn time-by-stories-list
  "Render list of times spent on individual stories, plus the total."
  [mouse-over]
  (let [options (subscribe [:options])
        stories (reaction (:stories @options))]
    (fn [mouse-over]
      (let [stories @stories]
        [:div.story-time
         [:div [:strong "Total time"] ": " (u/duration-string (:total-time mouse-over))]
         (for [[story v] (:time-by-story mouse-over)]
           (let [story-name (or (:story-name (get stories story)) "No story")]
             ^{:key story}
             [:div [:strong story-name] ": " (u/duration-string v)]))]))))

(defn pomodoro-bar-chart
  [pomodoro-stats chart-h title y-scale put-fn]
  (let [local (rc/atom {})]
    (fn [pomodoro-stats chart-h title y-scale put-fn]
      (let [indexed (map-indexed (fn [idx [k v]] [idx v]) pomodoro-stats)]
        [:div
         [:svg
          {:viewBox (str "0 0 600 " chart-h)}
          [:g
           [cc/chart-title "Time tracked"]
           [cc/bg-bars indexed local chart-h :pomodoro]
           [bars indexed local :total-time chart-h 0.0025 put-fn]
           [cc/path "M 0 50 l 600 0 z"]
           [cc/path "M 0 100 l 600 0 z"]]]
         (when-let [mouse-over (:mouse-over @local)]
           [time-by-stories-list mouse-over])
         [:svg
          {:viewBox (str "0 0 600 " chart-h)}
          [:g
           [cc/chart-title title]
           [cc/bg-bars indexed local chart-h :pomodoro]
           [bars indexed local :total chart-h y-scale put-fn]
           [bars indexed local :completed chart-h y-scale put-fn]
           [cc/path "M 0 50 l 600 0 z"]
           [cc/path "M 0 100 l 600 0 z"]]]
         (when-let [mouse-over (:mouse-over @local)]
           [:div.mouse-over-info (cc/info-div-pos @local)
            [:div.date (:date-string mouse-over)]
            [:div "Total: " (:total mouse-over)]
            [:div "Completed: " (:completed mouse-over)]
            [:div "Started: " (:started mouse-over)]
            [:div "Total time: " (u/duration-string (:total-time mouse-over))]])]))))
