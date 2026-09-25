<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>water</Name>
    <UserStyle>
      <Title>Water areas</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>large</Name>
          <ogc:Filter><ogc:PropertyIsGreaterThan><ogc:PropertyName>area</ogc:PropertyName><ogc:Literal>20000000</ogc:Literal></ogc:PropertyIsGreaterThan></ogc:Filter>
          <MinScaleDenominator>2000000</MinScaleDenominator>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#aad3df</CssParameter><CssParameter name="fill-opacity">1</CssParameter></Fill>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>medium</Name>
          <ogc:Filter><ogc:PropertyIsGreaterThan><ogc:PropertyName>area</ogc:PropertyName><ogc:Literal>200000</ogc:Literal></ogc:PropertyIsGreaterThan></ogc:Filter>
          <MinScaleDenominator>250000</MinScaleDenominator>
          <MaxScaleDenominator>2000000</MaxScaleDenominator>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#aad3df</CssParameter><CssParameter name="fill-opacity">1</CssParameter></Fill>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>all</Name>
          <MaxScaleDenominator>250000</MaxScaleDenominator>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#aad3df</CssParameter><CssParameter name="fill-opacity">1</CssParameter></Fill>
          </PolygonSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
