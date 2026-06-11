(ns demo.core-test
  (:require [clojure.string :as str]
            [clojure.test :refer [deftest is]]
            [demo.core :as core]))

(deftest greeting-test
  (is (str/includes? (core/greeting) "Hello from cljdemo"))
  (is (str/includes? (core/greeting) "42")))
