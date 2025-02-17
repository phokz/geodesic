#!/usr/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'typhoeus'
require 'json'
require 'geodesic_wgs84'
require 'pry'
require 'gnuplot'

wgs84 = Wgs84.new


def spherical_approx(point, d, bearing)
  # Given values
  lat1 = point.first * Math::PI / 180 # Convert to radians
  lon1 = point.last * Math::PI / 180 # Convert to radians

  r = 6371.0 # Earth's radius in km
  bearing = bearing * Math::PI / 180 # Convert to radians

  # Compute new latitude
  lat2 = Math.asin(Math.sin(lat1) * Math.cos(d / r) + Math.cos(lat1) * Math.sin(d / r) * Math.cos(bearing))

  # Compute new longitude
  lon2 = lon1 + Math.atan2(Math.sin(bearing) * Math.sin(d / r) * Math.cos(lat1),
                           Math.cos(d / r) - Math.sin(lat1) * Math.sin(lat2))

  # Convert back to degrees
  lat2 = lat2 * 180 / Math::PI
  lon2 = lon2 * 180 / Math::PI

  [lat2, lon2]
end

def query_api(points)
  positions = points.map do |point|
   "positions="+CGI.escape(point.reverse.map{|p| p.round(5) }.join(','))
  end.join('&')

  api_key = 'PASTE HERE'
  url = "https://api.mapy.cz/v1/elevation?lang=cs&#{positions}&apikey=#{api_key}"
  response = Typhoeus.get(url, headers: {accept: 'application/json'})

  JSON.parse(response.body)['items'].map{|i| i['elevation']}
end

def generate_elevations(points)

  elevations = []
  points.each_slice(100) do |sub_points|
    elevations << query_api(sub_points)
  end

  elevations.flatten

end


points = []

name = ARGV.shift
lat = ARGV.shift.to_f
lon = ARGV.shift.to_f

end_lat = ARGV.shift.to_f
end_lon = ARGV.shift.to_f
tower_height = ARGV.shift.to_f
parallel_distance = ARGV.shift.to_f

points << [lat,lon]
distance, bearing = wgs84.distance(lat, lon, end_lat, end_lon)
puts "Distance: #{distance}, bearing: #{bearing}"

left_bearing = bearing - 90
right_bearing = bearing + 90
left_points = [spherical_approx(points.last, parallel_distance / 1000.0, left_bearing)]
right_points = [spherical_approx(points.last, parallel_distance / 1000.0, right_bearing)]


number_points = 400

number_points.times do
  step_distance = distance / 1000.0 / number_points
  points << spherical_approx(points.last, step_distance, bearing)
  left_points << spherical_approx(left_points.last, step_distance, bearing)
  right_points << spherical_approx(right_points.last, step_distance, bearing)
end

elevations = generate_elevations(points)
left_elevations = generate_elevations(left_points)
right_elevations = generate_elevations(right_points)



total_distance = distance / 1000.0

# Create an array of distances, assuming the points are evenly spaced.
distances = Array.new(number_points) { |i| i * (total_distance.to_f / (number_points - 1)) }

# Building heights (in meters) at the start (A) and end (B) points
receiver_height = 10

height_A = tower_height + elevations.first
height_B = receiver_height + elevations.last

# Calculate the Line of Sight (LOS) at each distance along the path.
los = distances.map do |x|
  height_A + (height_B - height_A) * (x / total_distance)
end

# --- Plotting using gnuplot ---

Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    plot.terminal "png"

    # Plot title and labels
    plot.title  "#{name.gsub('_',' ')}: Elevation Profile and Direct Line of Sight"
    plot.xlabel "Distance (km)"
    plot.ylabel "Elevation (m)"
    plot.grid

    # Plot the terrain elevation as a green line
    plot.data << Gnuplot::DataSet.new([distances, elevations]) do |ds|
      ds.with = "lines"
      ds.title = "Terrain Elevation"
    end

    # Plot the terrain elevation as a green line
    plot.data << Gnuplot::DataSet.new([distances, left_elevations]) do |ds|
      ds.with = "lines"
      ds.title = "Left (ccw) Elevation - #{parallel_distance} m"
    end

    # Plot the terrain elevation as a green line
    plot.data << Gnuplot::DataSet.new([distances, right_elevations]) do |ds|
      ds.with = "lines"
      ds.title = "Right (cw) Elevation - #{parallel_distance} m"
    end

    # Plot the LOS as a red dashed line
    plot.data << Gnuplot::DataSet.new([distances, los]) do |ds|
      ds.with = "lines dt 2"  # 'dt 2' sets a dashed line style
      ds.title = "Direct Line of Sight"
    end

    # Plot building positions as blue points at the start and end of the path


    plot.data << Gnuplot::DataSet.new([[0], [height_A]]) do |ds|
      ds.with = "points pt 7 ps 1.5"  # pt 7 is a filled circle, ps sets point size
      ds.title = "Tower #{tower_height}m"
    end

    plot.data << Gnuplot::DataSet.new([[total_distance], [height_B]]) do |ds|
      ds.with = "points pt 7 ps 1.5"  # pt 7 is a filled circle, ps sets point size
      ds.title = "Receiver #{receiver_height}m"
    end

  plot.output "#{name}.png"
  end

end

