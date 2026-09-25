<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>roads</Name>
    <UserStyle>
      <Title>Roads</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>major</Name>
          <ogc:Filter><ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyName>rank</ogc:PropertyName><ogc:Literal>8</ogc:Literal></ogc:PropertyIsGreaterThanOrEqualTo></ogc:Filter>
          <MaxScaleDenominator>5000000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#e892a2</CssParameter><CssParameter name="stroke-width">1.5</CssParameter><CssParameter name="stroke-linecap">round</CssParameter></Stroke></LineSymbolizer>
        </Rule>
        <Rule>
          <Name>secondary</Name>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>rank</ogc:PropertyName><ogc:Literal>6</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>rank</ogc:PropertyName><ogc:Literal>7</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <MaxScaleDenominator>1000000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#f9b29c</CssParameter><CssParameter name="stroke-width">1.2</CssParameter><CssParameter name="stroke-linecap">round</CssParameter></Stroke></LineSymbolizer>
        </Rule>
        <Rule>
          <Name>minor</Name>
          <ogc:Filter><ogc:And><ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyName>rank</ogc:PropertyName><ogc:Literal>2</ogc:Literal></ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyIsLessThanOrEqualTo><ogc:PropertyName>rank</ogc:PropertyName><ogc:Literal>5</ogc:Literal></ogc:PropertyIsLessThanOrEqualTo></ogc:And></ogc:Filter>
          <MaxScaleDenominator>150000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#ffffff</CssParameter><CssParameter name="stroke-width">1</CssParameter><CssParameter name="stroke-linecap">round</CssParameter></Stroke></LineSymbolizer>
        </Rule>
        <Rule>
          <Name>paths</Name>
          <ogc:Filter><ogc:PropertyIsLessThanOrEqualTo><ogc:PropertyName>rank</ogc:PropertyName><ogc:Literal>1</ogc:Literal></ogc:PropertyIsLessThanOrEqualTo></ogc:Filter>
          <MaxScaleDenominator>35000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#999999</CssParameter><CssParameter name="stroke-width">0.6</CssParameter><CssParameter name="stroke-linecap">round</CssParameter><CssParameter name="stroke-dasharray">2 2</CssParameter></Stroke></LineSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
