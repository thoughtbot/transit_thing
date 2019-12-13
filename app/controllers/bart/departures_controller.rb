class Bart::DeparturesController < ApplicationController
  STATION = "POWL"
  KEY = "QIMZ-5MUJ-99PT-DWE9"
  BASE_URL = "http://api.bart.gov/api"
  ESTIMATES_URI = URI.parse(
    "#{BASE_URL}/etd.aspx?key=#{KEY}&orig=#{STATION}&json=y&cmd=etd",
  )

  DESTINATIONS = ["ANTC", "NCON", "PHIL", "PITT", "RICH", "24TH", "SFIA", "DALY", "DUBL"].freeze
  LONG_FORM_DESTINATIONS = ["Antioch", "North Concord/Martinez", "Pleasant Hill", "Pittsburg/Bay Point", "Richmond", "24th St. Mission (SF)", "San Francisco Int'l Airport", "Daly City", "Dublin/Pleasanton"].freeze

  def index
    response = JSON.parse(Net::HTTP.get(ESTIMATES_URI))
    estimates = build_estimates(response)
    formatted_estimates = format_estimates(estimates)
    LONG_FORM_DESTINATIONS.each do |destination|
      estimates = formatted_estimates[destination]&.sort_by{|estimate| estimate["eta"]}
      if !estimates
        formatted_estimates.delete(destination)
      end
    end

    advisories_url = URI.parse(
      "#{BASE_URL}/bsa.aspx?key=#{KEY}&json=y&cmd=bsa",
    )

    advisories = JSON.parse(Net::HTTP.get(advisories_url))
    message = ""
    advisories.dig("root", "bsa").each do |advisory|
      message = advisory.dig("description", "#cdata-section")
    end
    if message && message != "No delays reported."
      @advisory = message
    end
    @sorted_estimates = formatted_estimates.sort_by {|k,v| v.first["minutes"].to_i}
  end

  def build_estimates(response)
    all_destinations = response.dig("root", "station").first["etd"]
    trains = []
    DESTINATIONS.each do |desired_destination|
      match = all_destinations.detect { |destination|
        destination.fetch("abbreviation") == desired_destination
      }

      if match
        match.fetch("estimate").map {|x|
          if x["minutes"] != "LEAVING"
            eta = x["minutes"].to_i - 10
            leave_at = (Time.now + eta.minutes).strftime("%l:%M")
            x["eta"] = eta
            x["leave_at"] = leave_at
          else
            eta = 0
          end
        }
        match.fetch("estimate").reject! {|estimate| estimate["eta"] < 0}
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
