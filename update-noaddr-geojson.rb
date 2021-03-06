require 'httparty'

class BuildingsDownloader
  def download
    buildings = sorted_buildings(buildings(overpass_data))

    File.write('ulsk_buildings_no_addr.geojson', to_geojson(buildings))
    File.write('ulsk_buildings_no_addr.md', to_markdown(buildings))
  end

  private

  def overpass_query(query)
    i 'Querying Overpass API...'
    HTTParty.post('http://overpass.openstreetmap.fr/api/interpreter', body: query)
  end

  def overpass_data
    overpass_query <<-OverpassQL
      [out:json];
      (way(54.24, 48.26, 54.37, 48.42);) -> .all;
      (way.all["building"]; - way.all["addr:housenumber"];);
      (._; >>;);
      out skel;
    OverpassQL
  end

  def buildings(overpass_data)
    i 'Processing Overpass API data...'

    corners   = {}
    buildings = {}

    overpass_data['elements'].each do |element|
      case element['type']
        when 'node'
          corners[element['id']] = [element['lon'], element['lat']]
        when 'way'
          buildings[element['id']] = element['nodes'].map{|id| corners[id] }
      end
    end

    buildings
  end

  def sorted_buildings(buildings)
    i "Sorting #{buildings.size} buildings by area..."
    buildings.sort_by{|_, building| area(building) }.reverse
  end

  def area(corners)
    lats = []
    lons = []

    corners.each do |lat, lon|
      lats.push(lat)
      lons.push(lon)
    end

    y = lats.max - lats.min
    x = lons.max - lons.min

    x * y
  end

  def to_features(buildings)
    # TODO If a feature has a commonly used identifier, that identifier should be included as a member of the feature object with the name "id".
    buildings.map do |id, building|
      {
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates: [
            building
          ]
        },
        properties: {
          id: id
        }
      }
    end
  end

  def to_geojson(buildings)
    i 'Converting buildings to GeoJSON...'

    {type: 'FeatureCollection', features: to_features(buildings)}.to_json(indent: '   ', space: ' ', object_nl: "\n", array_nl: "\n")
  end

  def to_markdown(buildings)
    i 'Converting buildings to Markdown...'

    buildings.map{|id, _| "[#{id}](http://www.openstreetmap.org/way/#{id})" }.join("\n")
  end

  def i(message)
    puts message
  end
end

BuildingsDownloader.new.download
