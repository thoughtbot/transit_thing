class Bart::DeparturesController < ApplicationController
  STATION = "POWL"
  KEY = "QIMZ-5MUJ-99PT-DWE9"
  BASE_URL = "http://api.bart.gov/api"
  ESTIMATES_URI = URI.parse(
    "#{BASE_URL}/etd.aspx?key=#{KEY}&orig=#{STATION}&json=y&cmd=etd",
  )

  DESTINATIONS = ["ANTC", "NCON", "PHIL", "PITT", "RICH", "24TH", "SFIA", "DALY", "DUBL"].freeze
  LONG_FORM_DESTINATIONS = ["Antioch", "North Concord", "Pleasant Hill", "Pittsburg", "Richmond", "24th Street", "SFO", "Daly City", "Dublin"].freeze

  def index
    response = JSON.parse(Net::HTTP.get(ESTIMATES_URI))
    estimates = build_estimates(response)
    @formatted_estimates = format_estimates(estimates)
    @LONG_FORM_DESTINATIONS = LONG_FORM_DESTINATIONS
  end

  def build_estimates(response)
    all_destinations = response.dig("root", "station").first["etd"]
    trains = []
    DESTINATIONS.each do |desired_destination|
      match = all_destinations.detect { |destination|
        destination.fetch("abbreviation") == desired_destination
      }

      if match
        match.fetch("estimate").each do |estimate|
          trains << estimate.merge("destination" => match.fetch("destination"))
        end
      end
    end
    trains
  end

  def format_estimates(estimates)
    estimates.group_by {|estimate| estimate["destination"]}
  end
end
