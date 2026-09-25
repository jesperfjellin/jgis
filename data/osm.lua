-- osm2pgsql flex style: imports OSM into themed tables in the "osm" schema.
-- Geometries are stored in EPSG:3857 (osm2pgsql default), which matches what
-- web clients request, so GeoServer does not have to reproject.

local schema = 'osm'
local tables = {}

tables.buildings = osm2pgsql.define_area_table('buildings', {
    { column = 'fid', type = 'int8', not_null = true },
    { column = 'type', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'height', type = 'real' },
    { column = 'levels', type = 'int' },
    { column = 'area', type = 'real' },
    { column = 'geom', type = 'multipolygon', not_null = true },
}, { schema = schema })

tables.roads = osm2pgsql.define_way_table('roads', {
    { column = 'class', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'ref', type = 'text' },
    { column = 'oneway', type = 'bool' },
    { column = 'layer', type = 'int' },
    { column = 'rank', type = 'int', not_null = true },
    { column = 'geom', type = 'linestring', not_null = true },
}, { schema = schema })

tables.railways = osm2pgsql.define_way_table('railways', {
    { column = 'class', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'linestring', not_null = true },
}, { schema = schema })

tables.waterways = osm2pgsql.define_way_table('waterways', {
    { column = 'class', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'linestring', not_null = true },
}, { schema = schema })

tables.water = osm2pgsql.define_area_table('water', {
    { column = 'fid', type = 'int8', not_null = true },
    { column = 'class', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'area', type = 'real' },
    { column = 'geom', type = 'multipolygon', not_null = true },
}, { schema = schema })

tables.landcover = osm2pgsql.define_area_table('landcover', {
    { column = 'fid', type = 'int8', not_null = true },
    { column = 'class', type = 'text', not_null = true },
    { column = 'area', type = 'real' },
    { column = 'geom', type = 'multipolygon', not_null = true },
}, { schema = schema })

tables.pois = osm2pgsql.define_node_table('pois', {
    { column = 'class', type = 'text', not_null = true },
    { column = 'subclass', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'point', not_null = true },
}, { schema = schema })

tables.places = osm2pgsql.define_node_table('places', {
    { column = 'class', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'population', type = 'int' },
    { column = 'geom', type = 'point', not_null = true },
}, { schema = schema })

tables.boundaries = osm2pgsql.define_relation_table('boundaries', {
    { column = 'admin_level', type = 'int', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'multipolygon', not_null = true },
}, { schema = schema })

-- Road importance, used for filtering by scale (higher = more important).
local road_rank = {
    motorway = 10, trunk = 9, primary = 8, secondary = 7, tertiary = 6,
    motorway_link = 5, trunk_link = 5, primary_link = 5, secondary_link = 4, tertiary_link = 4,
    unclassified = 3, residential = 3, living_street = 2, service = 2, track = 1,
    pedestrian = 1, footway = 0, path = 0, cycleway = 0, bridleway = 0, steps = 0,
}

local railway_classes = { rail = true, light_rail = true, subway = true, tram = true, narrow_gauge = true }
local waterway_classes = { river = true, stream = true, canal = true, ditch = true, drain = true }

local landcover_landuse = {
    forest = 'forest', farmland = 'farmland', meadow = 'grass', grass = 'grass',
    residential = 'residential', industrial = 'industrial', commercial = 'commercial',
    retail = 'commercial', quarry = 'quarry', cemetery = 'cemetery', orchard = 'farmland',
}
local landcover_natural = {
    wood = 'forest', scrub = 'scrub', heath = 'heath', grassland = 'grass', wetland = 'wetland',
    bare_rock = 'rock', scree = 'rock', glacier = 'glacier', sand = 'sand', beach = 'sand',
}

local poi_keys = { 'amenity', 'shop', 'tourism', 'leisure', 'historic' }
local place_classes = { city = true, town = true, village = true, hamlet = true, suburb = true }

local function to_int(v)
    if v == nil then return nil end
    return math.tointeger(tonumber(v:match('^%-?%d+')))
end

local function to_real(v)
    if v == nil then return nil end
    return tonumber(v:match('^%d+%.?%d*'))
end

local function water_class(tags)
    if tags.natural == 'water' then return tags.water or 'water' end
    if tags.waterway == 'riverbank' then return 'river' end
    if tags.landuse == 'reservoir' or tags.landuse == 'basin' then return 'reservoir' end
    return nil
end

local function landcover_class(tags)
    return landcover_landuse[tags.landuse] or landcover_natural[tags.natural]
end

-- Areas shared by closed ways and multipolygon relations. "area" is measured in
-- EPSG:3857 units (inflated at high latitudes); use it for relative filtering only.
--
-- fid is the table's primary key (see post-import.sql). osm2pgsql's area_id is
-- negative for relations, and GeoServer's vector tile encoder needs non-negative
-- integer feature ids (MVT ids are unsigned); it logs a warning for every other
-- feature. fid is way id * 2 or relation id * 2 + 1, so it is unique and >= 0.
local function process_area(object, geom, fid)
    local tags = object.tags
    if tags.building and tags.building ~= 'no' then
        tables.buildings:insert({
            type = tags.building,
            name = tags.name,
            height = to_real(tags.height),
            levels = to_int(tags['building:levels']),
            area = geom:transform(3857):area(),
            fid = fid,
            geom = geom,
        })
        return
    end
    local wc = water_class(tags)
    if wc then
        tables.water:insert({ fid = fid, class = wc, name = tags.name, area = geom:transform(3857):area(), geom = geom })
        return
    end
    local lc = landcover_class(tags)
    if lc then
        tables.landcover:insert({ fid = fid, class = lc, area = geom:transform(3857):area(), geom = geom })
    end
end

function osm2pgsql.process_node(object)
    local tags = object.tags
    if tags.place and place_classes[tags.place] then
        tables.places:insert({
            class = tags.place,
            name = tags.name,
            population = to_int(tags.population),
            geom = object:as_point(),
        })
    end
    for _, key in ipairs(poi_keys) do
        if tags[key] then
            tables.pois:insert({
                class = key,
                subclass = tags[key],
                name = tags.name,
                geom = object:as_point(),
            })
            return
        end
    end
end

function osm2pgsql.process_way(object)
    local tags = object.tags

    if object.is_closed and tags.area ~= 'no' and not tags.highway then
        process_area(object, object:as_polygon(), object.id * 2)
    end

    if tags.highway and road_rank[tags.highway] and tags.area ~= 'yes' then
        tables.roads:insert({
            class = tags.highway,
            name = tags.name,
            ref = tags.ref,
            oneway = tags.oneway == 'yes',
            layer = to_int(tags.layer),
            rank = road_rank[tags.highway],
            geom = object:as_linestring(),
        })
    elseif tags.railway and railway_classes[tags.railway] then
        tables.railways:insert({ class = tags.railway, name = tags.name, geom = object:as_linestring() })
    elseif tags.waterway and waterway_classes[tags.waterway] then
        tables.waterways:insert({ class = tags.waterway, name = tags.name, geom = object:as_linestring() })
    end
end

function osm2pgsql.process_relation(object)
    local tags = object.tags
    if tags.type == 'multipolygon' then
        process_area(object, object:as_multipolygon(), object.id * 2 + 1)
    elseif tags.type == 'boundary' and tags.boundary == 'administrative' then
        local level = to_int(tags.admin_level)
        if level == 2 or level == 4 or level == 7 then
            tables.boundaries:insert({ admin_level = level, name = tags.name, geom = object:as_multipolygon() })
        end
    end
end
