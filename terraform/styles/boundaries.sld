<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>boundaries</Name>
    <UserStyle>
      <Title>Administrative boundaries</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>country</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>admin_level</ogc:PropertyName><ogc:Literal>2</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <PolygonSymbolizer>

            <Stroke><CssParameter name="stroke">#8d618b</CssParameter><CssParameter name="stroke-width">2</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>county</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>admin_level</ogc:PropertyName><ogc:Literal>4</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <MaxScaleDenominator>5000000</MaxScaleDenominator>
          <PolygonSymbolizer>

            <Stroke><CssParameter name="stroke">#8d618b</CssParameter><CssParameter name="stroke-width">1.2</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>municipality</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>admin_level</ogc:PropertyName><ogc:Literal>7</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <MaxScaleDenominator>1000000</MaxScaleDenominator>
          <PolygonSymbolizer>

            <Stroke><CssParameter name="stroke">#b28fb0</CssParameter><CssParameter name="stroke-width">0.8</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
