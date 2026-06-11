(ns demo.core
  (:require [medley.core :as m])
  (:gen-class))

(defn greeting []
  (str "Hello from cljdemo! " (m/map-vals inc {:answer 41})))

(defn -main [& _args]
  (println (greeting)))
