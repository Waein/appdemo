package cn.byb.appdemo.config;

import cn.fraudmetrix.forseti.fp.dubbo.DeviceInfoQuery;
import org.apache.dubbo.config.annotation.DubboReference;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * @date 2024-05-27
 * @sine v3.0.0
 * @description 设备指纹dubbo配置
 */
@Configuration
public class FpRpcConfig {

    @DubboReference(
            registry = {"saas"},
            check = false,
            version = "${dubbo.saas.version:}",
            retries = 0,
            parameters = {"timeout", "${dubbo.saas.timeout:}"})
    private DeviceInfoQuery deviceInfoQuery;

    @Bean
    public DeviceInfoQuery getDeviceInfoQuery() {
        return deviceInfoQuery;
    }
}
